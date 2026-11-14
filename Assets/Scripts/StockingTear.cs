using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// Paints tears (holes and runs) onto a stocking and sends them to the
/// stocking shader as a mask texture.
///
/// HOW IT WORKS
/// ─────────────
/// The component keeps a mask texture in the stocking's UV layout:
///     R = hole   (bare skin, ragged rolled edge)
///     G = run    (a thin ladder down the leg)
///
/// A tear is defined by a point on the stocking in its rest pose. For every
/// pixel of the mask, the component knows which point of the rest-pose surface
/// it belongs to, and measures the distance from the tear on the real 3D
/// surface. That keeps a tear round where the UVs are stretched and lets it
/// cross UV seams.
///
/// SETUP
/// ──────
/// 1. Add this component to the stocking object.
/// 2. In the Inspector, switch on "Tear Tool" and click on the stocking in the
///    Scene view. Hold Shift to paint the other tear type.
/// 3. "Restore" removes every tear.
///
/// Tears are kept in memory only. They are gone after a script reload or when
/// the scene is reopened.
/// </summary>
public enum StockingTearType
{
    Hole,
    Run
}

[ExecuteAlways]
[DisallowMultipleComponent]
public class StockingTear : MonoBehaviour
{
    [Header("New Tears")]
    [Tooltip("What a click creates. Hold Shift while clicking for the other type.")]
    public StockingTearType tearType = StockingTearType.Hole;

    [Tooltip("Radius of a new hole in metres.")]
    [Min(0.001f)]
    public float holeRadius = 0.02f;

    [Tooltip("How much longer a hole is along the leg than across it.")]
    [Range(1f, 3f)]
    public float holeStretch = 1.4f;

    [Tooltip("Length of a new run in metres.")]
    [Min(0.005f)]
    public float runLength = 0.15f;

    [Tooltip("Width of a new run in metres.")]
    [Min(0.0005f)]
    public float runWidth = 0.004f;

    [Header("Mesh")]
    [Tooltip("Mesh-space axis that points from the foot towards the hip. Runs follow it.")]
    public DenierAxis upAxis = DenierAxis.Y;

    [Tooltip("Metres per mesh unit. 0 = take it from this object's scale.")]
    [Min(0f)]
    public float metersPerMeshUnit = 0f;

    [Tooltip("Width and height of the tear mask in pixels.")]
    [Range(128, 1024)]
    public int maskResolution = 512;

    private static readonly int TearMaskId = Shader.PropertyToID("_TearMask");
    private static readonly int UseTearMaskId = Shader.PropertyToID("_UseTearMask");

    private struct Tear
    {
        public StockingTearType type;
        public Vector3 restPosition;   // mesh space, rest pose
    }

    private readonly List<Tear> tears = new List<Tear>();

    private Renderer targetRenderer;
    private SkinnedMeshRenderer skinnedRenderer;
    private Mesh sourceMesh;
    private Vector3[] restVertices;
    private Vector2[] meshUV;
    private int[] triangles;

    private int size;
    private Vector3[] texelRestPosition;   // rest-pose surface point of every mask pixel
    private bool[] texelValid;
    private Color32[] pixels;
    private Texture2D maskTexture;

    private Vector3[] posedVertices;
    private Matrix4x4[] skinMatrices;
    private MaterialPropertyBlock propertyBlock;
    private bool ready;
    private bool warned;

    public int TearCount => tears.Count;

    private void OnEnable()
    {
        Initialise();
    }

    private void OnDisable()
    {
        Release();
    }

    private void LateUpdate()
    {
        if (!ready || CurrentMesh() != sourceMesh || size != maskResolution)
            Initialise();

        // Re-applied every frame, because another component may have reset
        // the renderer's property block.
        if (ready)
            ApplyToRenderer();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Public API
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Tears the stocking where a world-space ray hits it. Returns false if
    /// the ray misses.
    /// </summary>
    public bool TearAtRay(Ray worldRay, StockingTearType type)
    {
        if (!ready) Initialise();
        if (!ready) return false;

        if (!Raycast(worldRay, out Vector3 restPosition))
            return false;

        AddTear(restPosition, type);
        return true;
    }

    /// <summary>Adds a tear at a point given in mesh space, rest pose.</summary>
    public void AddTear(Vector3 restPosition, StockingTearType type)
    {
        if (!ready) Initialise();
        if (!ready) return;

        Tear tear = new Tear { type = type, restPosition = restPosition };
        tears.Add(tear);
        PaintTear(tear);
        UploadMask();
    }

    /// <summary>Adds a tear at a random place on the stocking.</summary>
    public void AddRandomTear(StockingTearType type)
    {
        if (!ready) Initialise();
        if (!ready) return;

        int t = Random.Range(0, triangles.Length / 3) * 3;
        float a = Random.value;
        float b = Random.value;
        if (a + b > 1f) { a = 1f - a; b = 1f - b; }

        Vector3 position = restVertices[triangles[t]] * (1f - a - b)
                         + restVertices[triangles[t + 1]] * a
                         + restVertices[triangles[t + 2]] * b;
        AddTear(position, type);
    }

    /// <summary>Removes every tear and restores the stocking.</summary>
    public void ClearTears()
    {
        tears.Clear();
        if (!ready) return;

        for (int i = 0; i < pixels.Length; i++)
            pixels[i] = new Color32(0, 0, 0, 255);
        UploadMask();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Setup
    // ══════════════════════════════════════════════════════════════════════════

    private Mesh CurrentMesh()
    {
        if (skinnedRenderer != null) return skinnedRenderer.sharedMesh;
        MeshFilter filter = GetComponent<MeshFilter>();
        return filter != null ? filter.sharedMesh : null;
    }

    private void Initialise()
    {
        Release();

        targetRenderer = GetComponent<Renderer>();
        skinnedRenderer = GetComponent<SkinnedMeshRenderer>();
        sourceMesh = CurrentMesh();

        if (targetRenderer == null || sourceMesh == null)
            return;

        restVertices = sourceMesh.vertices;
        meshUV = sourceMesh.uv;
        triangles = sourceMesh.triangles;

        if (restVertices.Length == 0 || triangles.Length < 3 || meshUV.Length != restVertices.Length)
        {
            if (!warned)
            {
                warned = true;
                Debug.LogWarning("[StockingTear] Inactive: the mesh needs vertices, triangles and UVs.", this);
            }
            return;
        }

        size = Mathf.Clamp(maskResolution, 128, 1024);
        BuildRestPositionMap();

        pixels = new Color32[size * size];
        for (int i = 0; i < pixels.Length; i++)
            pixels[i] = new Color32(0, 0, 0, 255);

        maskTexture = new Texture2D(size, size, TextureFormat.RGBA32, true, true);
        maskTexture.name = "StockingTear Mask";
        maskTexture.hideFlags = HideFlags.HideAndDontSave;
        maskTexture.wrapMode = TextureWrapMode.Clamp;
        maskTexture.filterMode = FilterMode.Bilinear;

        propertyBlock = new MaterialPropertyBlock();
        ready = true;

        // Tears survive a change of resolution or mesh: repaint them.
        foreach (Tear tear in tears)
            PaintTear(tear);

        UploadMask();
    }

    private void Release()
    {
        ready = false;

        if (targetRenderer != null && propertyBlock != null)
        {
            targetRenderer.GetPropertyBlock(propertyBlock);
            propertyBlock.SetTexture(TearMaskId, Texture2D.blackTexture);
            propertyBlock.SetFloat(UseTearMaskId, 0f);
            targetRenderer.SetPropertyBlock(propertyBlock);
        }

        DestroyTemporary(maskTexture);
        maskTexture = null;
    }

    private static void DestroyTemporary(Object target)
    {
        if (target == null) return;
        if (Application.isPlaying) Destroy(target);
        else DestroyImmediate(target);
    }

    private float MeshUnitsPerMetre()
    {
        float scale = metersPerMeshUnit;
        if (scale <= 0f)
        {
            Vector3 ls = transform.lossyScale;
            scale = (Mathf.Abs(ls.x) + Mathf.Abs(ls.y) + Mathf.Abs(ls.z)) / 3f;
            if (scale <= 1e-8f) scale = 1f;
        }
        return 1f / scale;
    }

    private static Vector3 AxisVector(DenierAxis axis)
    {
        switch (axis)
        {
            case DenierAxis.X:         return Vector3.right;
            case DenierAxis.Y:         return Vector3.up;
            case DenierAxis.Z:         return Vector3.forward;
            case DenierAxis.NegativeX: return Vector3.left;
            case DenierAxis.NegativeY: return Vector3.down;
            default:                   return Vector3.back;
        }
    }

    /// <summary>
    /// Draws every triangle into UV space and stores, for each mask pixel, the
    /// rest-pose surface point it shows.
    /// </summary>
    private void BuildRestPositionMap()
    {
        texelRestPosition = new Vector3[size * size];
        texelValid = new bool[size * size];

        for (int t = 0; t + 2 < triangles.Length; t += 3)
        {
            int i0 = triangles[t];
            int i1 = triangles[t + 1];
            int i2 = triangles[t + 2];

            Vector2 a = meshUV[i0] * size;
            Vector2 b = meshUV[i1] * size;
            Vector2 c = meshUV[i2] * size;

            float area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
            if (Mathf.Abs(area) < 1e-8f)
                continue;

            int minX = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.x, Mathf.Min(b.x, c.x))), 0, size - 1);
            int maxX = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.x, Mathf.Max(b.x, c.x))), 0, size - 1);
            int minY = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.y, Mathf.Min(b.y, c.y))), 0, size - 1);
            int maxY = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.y, Mathf.Max(b.y, c.y))), 0, size - 1);

            for (int y = minY; y <= maxY; y++)
            {
                for (int x = minX; x <= maxX; x++)
                {
                    float px = x + 0.5f;
                    float py = y + 0.5f;

                    float w0 = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) / area;
                    float w1 = ((c.x - px) * (a.y - py) - (c.y - py) * (a.x - px)) / area;
                    float w2 = 1f - w0 - w1;

                    // Small tolerance so pixels on shared edges are not missed.
                    if (w0 < -0.02f || w1 < -0.02f || w2 < -0.02f)
                        continue;

                    int index = y * size + x;
                    texelRestPosition[index] = restVertices[i0] * w0
                                             + restVertices[i1] * w1
                                             + restVertices[i2] * w2;
                    texelValid[index] = true;
                }
            }
        }

        // Spread edge pixels outwards, so texture filtering at UV seams
        // still finds the tear.
        for (int pass = 0; pass < 3; pass++)
        {
            bool[] nextValid = (bool[])texelValid.Clone();

            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    int index = y * size + x;
                    if (texelValid[index]) continue;

                    int from = -1;
                    if (x > 0 && texelValid[index - 1]) from = index - 1;
                    else if (x < size - 1 && texelValid[index + 1]) from = index + 1;
                    else if (y > 0 && texelValid[index - size]) from = index - size;
                    else if (y < size - 1 && texelValid[index + size]) from = index + size;

                    if (from >= 0)
                    {
                        texelRestPosition[index] = texelRestPosition[from];
                        nextValid[index] = true;
                    }
                }
            }

            texelValid = nextValid;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Painting
    // ══════════════════════════════════════════════════════════════════════════

    private void PaintTear(Tear tear)
    {
        float unitsPerMetre = MeshUnitsPerMetre();
        Vector3 up = AxisVector(upAxis);

        if (tear.type == StockingTearType.Hole)
        {
            float radius = holeRadius * unitsPerMetre;

            for (int i = 0; i < pixels.Length; i++)
            {
                if (!texelValid[i]) continue;

                // Squash the distance along the leg, so the hole is taller than wide.
                Vector3 offset = texelRestPosition[i] - tear.restPosition;
                float along = Vector3.Dot(offset, up);
                offset -= up * (along * (1f - 1f / holeStretch));

                float d = offset.magnitude / radius;
                if (d >= 1f) continue;

                // Soft blob. The shader opens the hole where this passes 0.5,
                // which is at about three quarters of the radius.
                float falloff = 1f - Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.5f, 1f, d));
                byte value = (byte)Mathf.RoundToInt(falloff * 255f);
                if (value > pixels[i].r) pixels[i].r = value;
            }
        }
        else
        {
            float halfLength = runLength * 0.5f * unitsPerMetre;
            float width = runWidth * unitsPerMetre;
            Vector3 start = tear.restPosition - up * halfLength;
            Vector3 end = tear.restPosition + up * halfLength;
            Vector3 axis = end - start;
            float axisLengthSq = Mathf.Max(axis.sqrMagnitude, 1e-12f);

            for (int i = 0; i < pixels.Length; i++)
            {
                if (!texelValid[i]) continue;

                Vector3 p = texelRestPosition[i];
                float t = Mathf.Clamp01(Vector3.Dot(p - start, axis) / axisLengthSq);
                float d = (p - (start + axis * t)).magnitude / width;
                if (d >= 1f) continue;

                // Thin out towards both ends of the run.
                float taper = Mathf.SmoothStep(0f, 1f, Mathf.Min(t, 1f - t) * 5f);
                byte value = (byte)Mathf.RoundToInt((1f - Mathf.SmoothStep(0.3f, 1f, d)) * taper * 255f);
                if (value > pixels[i].g) pixels[i].g = value;
            }
        }
    }

    private void UploadMask()
    {
        if (maskTexture == null) return;

        maskTexture.SetPixels32(pixels);
        maskTexture.Apply(true);
        ApplyToRenderer();
    }

    private void ApplyToRenderer()
    {
        if (targetRenderer == null || maskTexture == null) return;

        targetRenderer.GetPropertyBlock(propertyBlock);
        propertyBlock.SetTexture(TearMaskId, maskTexture);
        propertyBlock.SetFloat(UseTearMaskId, 1f);
        targetRenderer.SetPropertyBlock(propertyBlock);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Ray hit on the posed mesh
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Fills posedVertices with the stocking's vertices in world space, in the
    /// current pose. A skinned mesh is skinned here from its bones and bind
    /// poses, which gives world positions directly whatever scale or rotation
    /// the model's hierarchy has. Blend shapes are not included.
    /// </summary>
    private bool UpdatePosedVertices()
    {
        int count = restVertices.Length;
        if (posedVertices == null || posedVertices.Length != count)
            posedVertices = new Vector3[count];

        if (skinnedRenderer == null)
        {
            Matrix4x4 toWorld = transform.localToWorldMatrix;
            for (int i = 0; i < count; i++)
                posedVertices[i] = toWorld.MultiplyPoint3x4(restVertices[i]);
            return true;
        }

        Transform[] bones = skinnedRenderer.bones;
        Matrix4x4[] bindposes = sourceMesh.bindposes;
        BoneWeight[] weights = sourceMesh.boneWeights;

        if (bones.Length == 0 || bindposes.Length != bones.Length || weights.Length != count)
        {
            // Not really skinned: treat it as a rigid mesh.
            Matrix4x4 toWorld = transform.localToWorldMatrix;
            for (int i = 0; i < count; i++)
                posedVertices[i] = toWorld.MultiplyPoint3x4(restVertices[i]);
            return true;
        }

        if (skinMatrices == null || skinMatrices.Length != bones.Length)
            skinMatrices = new Matrix4x4[bones.Length];

        for (int i = 0; i < bones.Length; i++)
        {
            skinMatrices[i] = bones[i] != null
                ? bones[i].localToWorldMatrix * bindposes[i]
                : Matrix4x4.identity;
        }

        for (int i = 0; i < count; i++)
        {
            BoneWeight w = weights[i];
            Vector3 v = restVertices[i];
            Vector3 p = Vector3.zero;

            if (w.weight0 > 0f) p += skinMatrices[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0;
            if (w.weight1 > 0f) p += skinMatrices[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1;
            if (w.weight2 > 0f) p += skinMatrices[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2;
            if (w.weight3 > 0f) p += skinMatrices[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;

            posedVertices[i] = p;
        }

        return true;
    }

    /// <summary>
    /// Finds where a world-space ray hits the stocking in its current pose and
    /// returns the matching point in the rest pose.
    /// </summary>
    private bool Raycast(Ray worldRay, out Vector3 restPosition)
    {
        restPosition = Vector3.zero;

        // Vertices in world space, in the current pose.
        if (!UpdatePosedVertices())
            return false;

        Vector3[] posed = posedVertices;
        Vector3 origin = worldRay.origin;
        Vector3 direction = worldRay.direction;

        float bestDistance = float.MaxValue;
        int bestTriangle = -1;
        float bestU = 0f, bestV = 0f;

        for (int t = 0; t + 2 < triangles.Length; t += 3)
        {
            Vector3 v0 = posed[triangles[t]];
            Vector3 edge1 = posed[triangles[t + 1]] - v0;
            Vector3 edge2 = posed[triangles[t + 2]] - v0;

            Vector3 h = Vector3.Cross(direction, edge2);
            float det = Vector3.Dot(edge1, h);
            if (Mathf.Abs(det) < 1e-12f) continue;

            float inv = 1f / det;
            Vector3 s = origin - v0;
            float u = Vector3.Dot(s, h) * inv;
            if (u < 0f || u > 1f) continue;

            Vector3 q = Vector3.Cross(s, edge1);
            float v = Vector3.Dot(direction, q) * inv;
            if (v < 0f || u + v > 1f) continue;

            float distance = Vector3.Dot(edge2, q) * inv;
            if (distance > 0f && distance < bestDistance)
            {
                bestDistance = distance;
                bestTriangle = t;
                bestU = u;
                bestV = v;
            }
        }

        if (bestTriangle < 0)
            return false;

        restPosition = restVertices[triangles[bestTriangle]] * (1f - bestU - bestV)
                     + restVertices[triangles[bestTriangle + 1]] * bestU
                     + restVertices[triangles[bestTriangle + 2]] * bestV;
        return true;
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Inspector with the Scene view tear tool
// ══════════════════════════════════════════════════════════════════════════════
#if UNITY_EDITOR
[CustomEditor(typeof(StockingTear))]
public class StockingTearEditor : Editor
{
    private bool toolActive;

    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        EditorGUILayout.Space(8);

        StockingTear tear = (StockingTear)target;

        Color previous = GUI.backgroundColor;
        if (toolActive) GUI.backgroundColor = new Color(1f, 0.78f, 0.3f);

        bool nowActive = GUILayout.Toggle(toolActive,
            toolActive ? "Tear Tool: ON (click the stocking in the Scene view)" : "Tear Tool: OFF",
            "Button", GUILayout.Height(32));
        if (nowActive != toolActive)
        {
            toolActive = nowActive;
            SceneView.RepaintAll();
        }

        GUI.backgroundColor = previous;

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("Add Random Hole")) tear.AddRandomTear(StockingTearType.Hole);
        if (GUILayout.Button("Add Random Run")) tear.AddRandomTear(StockingTearType.Run);
        EditorGUILayout.EndHorizontal();

        if (GUILayout.Button("Restore (remove all tears)"))
        {
            tear.ClearTears();
            SceneView.RepaintAll();
        }

        EditorGUILayout.HelpBox(
            $"Tears: {tear.TearCount}.\n" +
            "Click = the tear type selected above. Shift + click = the other type.\n" +
            "Tears are kept in memory only and are gone after a script reload.",
            MessageType.Info);
    }

    private void OnSceneGUI()
    {
        if (!toolActive)
            return;

        StockingTear tear = (StockingTear)target;
        Event current = Event.current;

        // Keep the click for this tool, so it does not change the selection.
        int controlId = GUIUtility.GetControlID(FocusType.Passive);
        if (current.type == EventType.Layout)
            HandleUtility.AddDefaultControl(controlId);

        if (current.type == EventType.MouseDown && current.button == 0 && !current.alt)
        {
            StockingTearType type = tear.tearType;
            if (current.shift)
            {
                type = type == StockingTearType.Hole ? StockingTearType.Run : StockingTearType.Hole;
            }

            Ray ray = HandleUtility.GUIPointToWorldRay(current.mousePosition);
            if (tear.TearAtRay(ray, type))
            {
                SceneView.RepaintAll();
            }
            else
            {
                Debug.Log("[StockingTear] The click did not hit the stocking.", tear);
            }

            // The tool owns the click either way, so it never changes the selection.
            current.Use();
        }
    }
}
#endif // UNITY_EDITOR
