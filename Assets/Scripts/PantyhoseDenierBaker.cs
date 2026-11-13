using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// Bakes stocking density data into mesh vertex colors for the
/// FabricPBR_ProceduralPattern (stocking) shader.
///
/// CHANNELS
/// ─────────
///   R = dense zone   manufactured reinforcement: welt, heel, toe.
///                    0 = normal sheer fabric, 1 = dense.
///   G = stretch      how much the fabric is stretched over the leg.
///                    0 = relaxed, 1 = fully stretched (sheerer).
///   B, A             left untouched.
///
/// HOW THE ZONES ARE FOUND
/// ────────────────────────
///   Welt   The open edge at the top of each stocking is detected from the
///          mesh boundary. Vertices within "Welt Width" of that edge are
///          marked dense.
///   Toe    On each leg, the front part of the foot within "Toe Length"
///          of the toe tip.
///   Heel   On each leg, the back part of the foot within "Heel Length"
///          of the rearmost point and below "Heel Height".
///
///   Legs are separated automatically: two mesh islands = two legs, or one
///   island (pantyhose) split down the middle.
///
/// STRETCH MODES
/// ──────────────
///   Synthetic Circumference   Uses this mesh only. Wider parts of the leg
///                             (thigh, calf) count as more stretched than the
///                             narrowest part (ankle).
///   Reference Area Stretch    Compares against a rest mesh with identical
///                             topology and measures real area change.
///   None                      Writes G = 0.
///
/// SHADER SETUP
/// ─────────────
///     ✔  "Vertex Red = Dense Zone"   (_UseDenierFromVertexR)
///     ✔  "Vertex Green = Stretch"    (_UseStretchFromVertexG)
///     •  Dense Zone Opacity          (_DenseZoneOpacity) opacity where R = 1
///     •  Stretch Makes Sheerer       (_StretchSheerness)
///
/// USAGE
/// ──────
/// 1. Add this component to the stocking GameObject (MeshFilter or
///    SkinnedMeshRenderer).
/// 2. Set the Up and Forward axes if the mesh is not Y-up / Z-forward.
/// 3. Click "Bake Denier Vertex Colors".
///
/// Meshes that live inside a model file (FBX) cannot store the result, so the
/// baker saves a copy as a .asset next to the model and assigns it.
/// </summary>
public enum DenierStretchMode
{
    ReferenceAreaStretch = 0,
    SyntheticCircumferenceStretch = 1,
    None = 2
}

public enum DenierAxis
{
    X, Y, Z, NegativeX, NegativeY, NegativeZ
}

public enum DenierLegLayout
{
    Auto,
    SingleLeg,
    TwoLegs
}

public class PantyhoseDenierBaker : MonoBehaviour
{
    // ─── Orientation ─────────────────────────────────────────────────────────
    [Header("Mesh Orientation (mesh space)")]
    [Tooltip("Axis that points from the foot towards the hip.")]
    public DenierAxis upAxis = DenierAxis.Y;

    [Tooltip("Axis that points from the heel towards the toes.")]
    public DenierAxis forwardAxis = DenierAxis.Z;

    [Tooltip("Auto: two mesh islands are two legs; a single island is split\n" +
             "down the middle if a gap is found between the feet.")]
    public DenierLegLayout legLayout = DenierLegLayout.Auto;

    [Tooltip("Metres per mesh unit. 0 = take it from this object's scale.\n" +
             "Check the leg height printed in the Console after a bake: if it\n" +
             "is not a believable number of metres, set this by hand.")]
    [Min(0f)]
    public float metersPerMeshUnit = 0f;

    // ─── Dense Zones (Red channel) ───────────────────────────────────────────
    [Header("Dense Zones (Red Channel)")]
    [Tooltip("Density written at the welt (top band). 0 = no welt.")]
    [Range(0f, 1f)]
    public float weltDensity = 1.0f;

    [Tooltip("Width of the welt band in metres, measured from the top open edge.")]
    [Min(0f)]
    public float weltWidth = 0.05f;

    [Tooltip("Density written at the toe cap. 0 = no toe zone.")]
    [Range(0f, 1f)]
    public float toeDensity = 1.0f;

    [Tooltip("Length of the toe cap in metres, measured back from the toe tip.")]
    [Min(0f)]
    public float toeLength = 0.05f;

    [Tooltip("Density written at the heel. 0 = no heel zone.")]
    [Range(0f, 1f)]
    public float heelDensity = 1.0f;

    [Tooltip("Length of the heel zone in metres, measured forward from the\n" +
             "rearmost point of the foot.")]
    [Min(0f)]
    public float heelLength = 0.06f;

    [Tooltip("Height of the heel zone in metres above the sole.")]
    [Min(0f)]
    public float heelHeight = 0.07f;

    [Tooltip("Height in metres above the sole that counts as the foot.\n" +
             "Toe and heel zones are only looked for below this height.")]
    [Min(0.001f)]
    public float footHeight = 0.09f;

    [Tooltip("Soft edge of every zone in metres.")]
    [Min(0.0001f)]
    public float zoneFeather = 0.015f;

    [Tooltip("Smoothing passes over the finished zones. Evens out ragged zone\n" +
             "borders on low-poly meshes. 0 = off.")]
    [Range(0, 8)]
    public int zoneSmoothingPasses = 2;

    [Header("Density Mask Texture")]
    [Tooltip("Also bakes the dense zones into a texture and assigns it to the\n" +
             "material's Density Mask slot. The zones are computed per pixel, so\n" +
             "their borders are sharp even on a low-poly mesh. Needs UVs that do\n" +
             "not overlap.")]
    public bool bakeDensityMaskTexture = true;

    [Tooltip("Width and height of the mask texture in pixels.")]
    [Range(128, 2048)]
    public int maskResolution = 1024;

    // ─── Stretch (Green channel) ─────────────────────────────────────────────
    [Header("Stretch (Green Channel)")]
    public DenierStretchMode stretchMode = DenierStretchMode.SyntheticCircumferenceStretch;

    [Tooltip("Rest mesh with the same vertices and triangles as this mesh.\n" +
             "Used only in Reference Area Stretch mode.")]
    public Mesh referenceRestMesh;

    [Tooltip("Number of slices along the leg used by Synthetic Circumference mode.")]
    [Range(8, 256)]
    public int syntheticSliceCount = 48;

    [Tooltip("Stretch ratio that counts as relaxed (G = Min Stretch).\n" +
             "Synthetic mode: radius / ankle radius. Reference mode: area ratio.")]
    [Min(0.01f)]
    public float stretchRatioAtRelaxed = 1.0f;

    [Tooltip("Stretch ratio that counts as fully stretched (G = Max Stretch).\n" +
             "Synthetic mode: about 2 (thigh is twice the ankle radius).\n" +
             "Reference mode: about 1.25.\n" +
             "The measured range is printed in the Console after a bake.")]
    [Min(0.01f)]
    public float stretchRatioAtFull = 2.0f;

    [Tooltip("Curve applied to the stretch. 1 = linear.")]
    [Range(0.2f, 5f)]
    public float stretchContrastPower = 1.0f;

    [Range(0f, 1f)]
    public float minStretch = 0.0f;

    [Range(0f, 1f)]
    public float maxStretch = 1.0f;

    [Tooltip("Smoothing passes over the stretch values.")]
    [Range(0, 16)]
    public int smoothingPasses = 4;

#if UNITY_EDITOR

    // ══════════════════════════════════════════════════════════════════════════
    // Entry Point
    // ══════════════════════════════════════════════════════════════════════════

    [ContextMenu("Bake Denier Vertex Colors")]
    public void BakeDenierVertexColors()
    {
        MeshFilter mf = GetComponent<MeshFilter>();
        SkinnedMeshRenderer smr = GetComponent<SkinnedMeshRenderer>();

        Mesh sourceMesh = null;
        if (smr != null) sourceMesh = smr.sharedMesh;
        else if (mf != null) sourceMesh = mf.sharedMesh;

        if (sourceMesh == null)
        {
            Debug.LogError("[DenierBaker] No mesh found. Add this component to an object " +
                           "with a MeshFilter or SkinnedMeshRenderer.", this);
            return;
        }

        Vector3[] vertices  = sourceMesh.vertices;
        int[]     triangles = sourceMesh.triangles;
        int       vertCount = vertices.Length;

        if (vertCount == 0 || triangles.Length < 3)
        {
            Debug.LogError("[DenierBaker] Mesh has no vertices or triangles.", this);
            return;
        }

        Vector3 up = AxisVector(upAxis);
        Vector3 forward = AxisVector(forwardAxis);
        if (Mathf.Abs(Vector3.Dot(up, forward)) > 0.5f)
        {
            Debug.LogError("[DenierBaker] Up Axis and Forward Axis must be different axes.", this);
            return;
        }
        Vector3 right = Vector3.Cross(up, forward);

        float scale = metersPerMeshUnit;
        if (scale <= 0f)
        {
            Vector3 ls = transform.lossyScale;
            scale = (Mathf.Abs(ls.x) + Mathf.Abs(ls.y) + Mathf.Abs(ls.z)) / 3f;
            if (scale <= 1e-8f) scale = 1f;
        }

        // Positions in metres, in the leg frame.
        float[] h = new float[vertCount];   // height (foot → hip)
        float[] f = new float[vertCount];   // forward (heel → toe)
        float[] s = new float[vertCount];   // sideways
        for (int i = 0; i < vertCount; i++)
        {
            Vector3 p = vertices[i] * scale;
            h[i] = Vector3.Dot(p, up);
            f[i] = Vector3.Dot(p, forward);
            s[i] = Vector3.Dot(p, right);
        }

        // ── Topology ──────────────────────────────────────────────────────────
        // Vertices are welded by position first: imported meshes split vertices
        // at UV seams, which would otherwise look like open edges.
        int[] canon = BuildCanonicalIndices(vertices);
        HashSet<int>[] canonAdj = BuildCanonicalAdjacency(vertCount, triangles, canon);
        List<int>[] adj = ExpandAdjacency(canonAdj, canon);
        int[] component = BuildComponents(vertCount, triangles, canon, out int componentCount);

        // ── Legs ──────────────────────────────────────────────────────────────
        int[] leg = AssignLegs(h, s, component, componentCount, out int legCount, out string legInfo);

        float[] legMinH = new float[legCount];
        float[] legMaxH = new float[legCount];
        for (int l = 0; l < legCount; l++) { legMinH[l] = float.MaxValue; legMaxH[l] = float.MinValue; }
        for (int i = 0; i < vertCount; i++)
        {
            int l = leg[i];
            if (h[i] < legMinH[l]) legMinH[l] = h[i];
            if (h[i] > legMaxH[l]) legMaxH[l] = h[i];
        }

        // 1 inside the foot, fading to 0 above it.
        float[] footMask = new float[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            float above = h[i] - legMinH[leg[i]];
            footMask[i] = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.InverseLerp(footHeight, footHeight + zoneFeather, above));
        }

        // ── Red: dense zones ─────────────────────────────────────────────────
        float[] dense = new float[vertCount];
        int weltLoops = 0;
        List<int>[] weltSegments = null;

        if (weltDensity > 0f && weltWidth > 0f)
        {
            float[] weltDist = ComputeWeltDistance(
                vertices, scale, triangles, canon, component, componentCount, h,
                out weltLoops, out weltSegments);

            for (int i = 0; i < vertCount; i++)
            {
                float d = weltDist[canon[i]];
                float m = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(weltWidth, weltWidth + zoneFeather, d));
                dense[i] = Mathf.Max(dense[i], m * weltDensity);
            }

            if (weltLoops == 0)
            {
                Debug.LogWarning("[DenierBaker] No open top edge found, so no welt was baked. " +
                                 "The stocking mesh needs an open edge at the top.", this);
            }
        }

        // Toe tip and rearmost point of each foot.
        float[] legTipF = new float[legCount];
        float[] legRearF = new float[legCount];
        for (int l = 0; l < legCount; l++) { legTipF[l] = float.MinValue; legRearF[l] = float.MaxValue; }
        for (int i = 0; i < vertCount; i++)
        {
            int l = leg[i];
            if (h[i] - legMinH[l] > footHeight) continue;
            if (f[i] > legTipF[l]) legTipF[l] = f[i];
            if (f[i] < legRearF[l]) legRearF[l] = f[i];
        }

        for (int i = 0; i < vertCount; i++)
        {
            int l = leg[i];
            if (legTipF[l] == float.MinValue) continue;

            if (toeDensity > 0f && toeLength > 0f)
            {
                float fromTip = legTipF[l] - f[i];
                float m = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(toeLength, toeLength + zoneFeather, fromTip));
                dense[i] = Mathf.Max(dense[i], m * footMask[i] * toeDensity);
            }

            if (heelDensity > 0f && heelLength > 0f)
            {
                float fromRear = f[i] - legRearF[l];
                float above = h[i] - legMinH[l];
                float mLen = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(heelLength, heelLength + zoneFeather, fromRear));
                float mHgt = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(heelHeight, heelHeight + zoneFeather, above));
                dense[i] = Mathf.Max(dense[i], mLen * mHgt * heelDensity);
            }
        }

        for (int pass = 0; pass < zoneSmoothingPasses; pass++)
            SmoothOnGraph(dense, adj);

        // ── Green: stretch ───────────────────────────────────────────────────
        float[] stretch = new float[vertCount];
        string stretchInfo = "none";

        if (stretchMode != DenierStretchMode.None)
        {
            float[] ratio = null;
            string failureReason = string.Empty;
            bool ok;

            if (stretchMode == DenierStretchMode.ReferenceAreaStretch)
            {
                ok = TryBuildAreaStretchMetric(sourceMesh, referenceRestMesh, out ratio, out failureReason);
                stretchInfo = "reference-area";
            }
            else
            {
                ok = TryBuildCircumferenceMetric(h, f, s, leg, legCount, legMinH, legMaxH,
                    footMask, out ratio, out failureReason);
                stretchInfo = "synthetic-circumference";
            }

            if (!ok)
            {
                Debug.LogWarning("[DenierBaker] Stretch could not be baked: " + failureReason +
                                 " G is written as 0.", this);
                stretchInfo = "none (failed)";
            }
            else
            {
                for (int pass = 0; pass < smoothingPasses; pass++)
                    SmoothOnGraph(ratio, adj);

                float minR = float.MaxValue, maxR = float.MinValue;
                float relaxed = Mathf.Max(0.01f, stretchRatioAtRelaxed);
                float full = Mathf.Max(relaxed + 1e-4f, stretchRatioAtFull);

                for (int i = 0; i < vertCount; i++)
                {
                    if (ratio[i] < minR) minR = ratio[i];
                    if (ratio[i] > maxR) maxR = ratio[i];

                    float t = Mathf.InverseLerp(relaxed, full, ratio[i]);
                    t = Mathf.Pow(t, stretchContrastPower);
                    stretch[i] = Mathf.Lerp(minStretch, maxStretch, t);
                }

                stretchInfo += $", measured ratio {minR:F2} to {maxR:F2}";
            }
        }

        // ── Write colors ─────────────────────────────────────────────────────
        Color[] existingColors = sourceMesh.colors;
        bool    hasColors      = existingColors != null && existingColors.Length == vertCount;
        Color[] newColors      = new Color[vertCount];

        for (int i = 0; i < vertCount; i++)
        {
            Color prev = hasColors ? existingColors[i] : new Color(0f, 0f, 0f, 1f);
            newColors[i] = new Color(Mathf.Clamp01(dense[i]), Mathf.Clamp01(stretch[i]), prev.b, prev.a);
        }

        Mesh targetMesh = GetWritableMesh(sourceMesh, smr, mf);
        if (targetMesh == null)
            return;

        Undo.RecordObject(targetMesh, "Bake Denier Vertex Colors");
        targetMesh.colors = newColors;
        EditorUtility.SetDirty(targetMesh);
        AssetDatabase.SaveAssets();

        string maskInfo = "off";
        if (bakeDensityMaskTexture)
        {
            maskInfo = BakeDensityMask(
                targetMesh, vertices, triangles, sourceMesh.uv, scale, up, forward,
                leg, component, legMinH, legTipF, legRearF, weltSegments);
        }

        float tallest = 0f;
        for (int l = 0; l < legCount; l++)
            tallest = Mathf.Max(tallest, legMaxH[l] - legMinH[l]);

        Debug.Log(
            $"[DenierBaker] Done on '{targetMesh.name}'. Legs: {legCount} ({legInfo}), " +
            $"leg height {tallest:F2} m, welt edges found: {weltLoops}, stretch: {stretchInfo}, " +
            $"mask texture: {maskInfo}.",
            this);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Density mask texture
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Dense-zone value (0..1) at any point on the surface. Same rules as the
    /// per-vertex bake, but usable per pixel.
    /// </summary>
    private float EvaluateDenseAt(
        Vector3 meshPosition, Vector3[] vertices, float scale, Vector3 up, Vector3 forward,
        float minHeight, float tipForward, float rearForward, List<int> weltEdge)
    {
        Vector3 p = meshPosition * scale;
        float height = Vector3.Dot(p, up) - minHeight;
        float along = Vector3.Dot(p, forward);
        float dense = 0f;

        if (weltDensity > 0f && weltWidth > 0f && weltEdge != null && weltEdge.Count > 0)
        {
            float best = float.MaxValue;
            for (int k = 0; k < weltEdge.Count; k += 2)
            {
                float d = PointSegmentDistance(
                    meshPosition, vertices[weltEdge[k]], vertices[weltEdge[k + 1]]);
                if (d < best) best = d;
            }

            float m = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.InverseLerp(weltWidth, weltWidth + zoneFeather, best * scale));
            dense = Mathf.Max(dense, m * weltDensity);
        }

        if (tipForward != float.MinValue)
        {
            float foot = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.InverseLerp(footHeight, footHeight + zoneFeather, height));

            if (toeDensity > 0f && toeLength > 0f)
            {
                float m = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(toeLength, toeLength + zoneFeather, tipForward - along));
                dense = Mathf.Max(dense, m * foot * toeDensity);
            }

            if (heelDensity > 0f && heelLength > 0f)
            {
                float mLen = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(heelLength, heelLength + zoneFeather, along - rearForward));
                float mHgt = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.InverseLerp(heelHeight, heelHeight + zoneFeather, height));
                dense = Mathf.Max(dense, mLen * mHgt * heelDensity);
            }
        }

        return Mathf.Clamp01(dense);
    }

    /// <summary>
    /// Draws every triangle into UV space and evaluates the dense zones for
    /// each pixel it covers. Saves the result as a PNG next to the mesh and
    /// assigns it to the stocking material. Returns a short status text.
    /// </summary>
    private string BakeDensityMask(
        Mesh targetMesh, Vector3[] vertices, int[] triangles, Vector2[] uv,
        float scale, Vector3 up, Vector3 forward,
        int[] leg, int[] component, float[] legMinH, float[] legTipF, float[] legRearF,
        List<int>[] weltSegments)
    {
        if (uv == null || uv.Length != vertices.Length)
        {
            Debug.LogWarning("[DenierBaker] The mesh has no UVs, so no mask texture was baked.", this);
            return "skipped (no UVs)";
        }

        int size = Mathf.Clamp(maskResolution, 128, 2048);
        float[] mask = new float[size * size];
        bool[] filled = new bool[size * size];

        int triangleCount = triangles.Length / 3;
        for (int t = 0; t < triangleCount; t++)
        {
            if ((t & 255) == 0)
            {
                EditorUtility.DisplayProgressBar("Bake Density Mask",
                    "Drawing dense zones into the texture", (float)t / triangleCount);
            }

            int i0 = triangles[t * 3];
            int i1 = triangles[t * 3 + 1];
            int i2 = triangles[t * 3 + 2];

            Vector2 a = uv[i0] * size;
            Vector2 b = uv[i1] * size;
            Vector2 c = uv[i2] * size;

            float area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
            if (Mathf.Abs(area) < 1e-8f)
                continue;

            int minX = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.x, Mathf.Min(b.x, c.x))), 0, size - 1);
            int maxX = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.x, Mathf.Max(b.x, c.x))), 0, size - 1);
            int minY = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.y, Mathf.Min(b.y, c.y))), 0, size - 1);
            int maxY = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.y, Mathf.Max(b.y, c.y))), 0, size - 1);

            int legIndex = leg[i0];
            List<int> weltEdge = weltSegments != null ? weltSegments[component[i0]] : null;

            for (int y = minY; y <= maxY; y++)
            {
                for (int x = minX; x <= maxX; x++)
                {
                    float px = x + 0.5f;
                    float py = y + 0.5f;

                    // Barycentric weights of the pixel centre.
                    float w0 = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) / area;
                    float w1 = ((c.x - px) * (a.y - py) - (c.y - py) * (a.x - px)) / area;
                    float w2 = 1f - w0 - w1;

                    // Small tolerance so pixels on shared edges are not missed.
                    if (w0 < -0.02f || w1 < -0.02f || w2 < -0.02f)
                        continue;

                    Vector3 position = vertices[i0] * w0 + vertices[i1] * w1 + vertices[i2] * w2;
                    float value = EvaluateDenseAt(
                        position, vertices, scale, up, forward,
                        legMinH[legIndex], legTipF[legIndex], legRearF[legIndex], weltEdge);

                    int index = y * size + x;
                    if (!filled[index] || value > mask[index])
                        mask[index] = value;
                    filled[index] = true;
                }
            }
        }

        // Spread the edge pixels outwards a little, so texture filtering does
        // not pull in empty pixels at UV seams.
        for (int pass = 0; pass < 4; pass++)
        {
            bool[] nextFilled = (bool[])filled.Clone();
            float[] nextMask = (float[])mask.Clone();

            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    int index = y * size + x;
                    if (filled[index]) continue;

                    float best = -1f;
                    if (x > 0 && filled[index - 1]) best = Mathf.Max(best, mask[index - 1]);
                    if (x < size - 1 && filled[index + 1]) best = Mathf.Max(best, mask[index + 1]);
                    if (y > 0 && filled[index - size]) best = Mathf.Max(best, mask[index - size]);
                    if (y < size - 1 && filled[index + size]) best = Mathf.Max(best, mask[index + size]);

                    if (best >= 0f)
                    {
                        nextMask[index] = best;
                        nextFilled[index] = true;
                    }
                }
            }

            filled = nextFilled;
            mask = nextMask;
        }

        EditorUtility.ClearProgressBar();

        Color32[] pixels = new Color32[size * size];
        for (int i = 0; i < pixels.Length; i++)
        {
            byte v = (byte)Mathf.RoundToInt(Mathf.Clamp01(mask[i]) * 255f);
            pixels[i] = new Color32(v, v, v, 255);
        }

        Texture2D texture = new Texture2D(size, size, TextureFormat.RGB24, false, true);
        texture.SetPixels32(pixels);
        byte[] png = texture.EncodeToPNG();
        DestroyImmediate(texture);

        // Same file every bake, so the material keeps pointing at it.
        string folder = "Assets";
        string meshPath = AssetDatabase.GetAssetPath(targetMesh);
        if (!string.IsNullOrEmpty(meshPath) && meshPath.StartsWith("Assets/"))
        {
            int slash = meshPath.LastIndexOf('/');
            if (slash > 0) folder = meshPath.Substring(0, slash);
        }

        string texturePath = folder + "/" + targetMesh.name + "_DensityMask.png";
        System.IO.File.WriteAllBytes(texturePath, png);
        AssetDatabase.ImportAsset(texturePath);

        TextureImporter importer = AssetImporter.GetAtPath(texturePath) as TextureImporter;
        if (importer != null)
        {
            importer.sRGBTexture = false;
            importer.mipmapEnabled = true;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.SaveAndReimport();
        }

        Texture2D maskAsset = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);

        // Assign it to every stocking material on this object.
        Renderer targetRenderer = GetComponent<Renderer>();
        int assigned = 0;
        if (targetRenderer != null && maskAsset != null)
        {
            foreach (Material material in targetRenderer.sharedMaterials)
            {
                if (material == null || !material.HasProperty("_DensityMask"))
                    continue;

                Undo.RecordObject(material, "Assign Density Mask");
                material.SetTexture("_DensityMask", maskAsset);
                material.SetFloat("_UseDensityMask", 1f);

                // The texture replaces the softer per-vertex zones.
                if (material.HasProperty("_UseDenierFromVertexR"))
                    material.SetFloat("_UseDenierFromVertexR", 0f);

                EditorUtility.SetDirty(material);
                assigned++;
            }
        }

        return $"'{texturePath}' ({size} px), assigned to {assigned} material(s)";
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Saving
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Returns a mesh the result can be saved into. A mesh inside a model file
    /// (FBX) or a built-in mesh loses its changes on reimport, so a copy is
    /// saved as a .asset and assigned to the renderer.
    /// </summary>
    private Mesh GetWritableMesh(Mesh sourceMesh, SkinnedMeshRenderer smr, MeshFilter mf)
    {
        string path = AssetDatabase.GetAssetPath(sourceMesh);
        bool standalone = !string.IsNullOrEmpty(path)
                          && path.StartsWith("Assets/")
                          && path.EndsWith(".asset");
        if (standalone)
            return sourceMesh;

        string folder = "Assets";
        if (!string.IsNullOrEmpty(path) && path.StartsWith("Assets/"))
        {
            int slash = path.LastIndexOf('/');
            if (slash > 0) folder = path.Substring(0, slash);
        }

        Mesh copy = Instantiate(sourceMesh);
        copy.name = sourceMesh.name + "_Denier";

        string newPath = AssetDatabase.GenerateUniqueAssetPath(folder + "/" + copy.name + ".asset");
        AssetDatabase.CreateAsset(copy, newPath);

        if (smr != null)
        {
            Undo.RecordObject(smr, "Assign Baked Denier Mesh");
            smr.sharedMesh = copy;
            EditorUtility.SetDirty(smr);
        }
        else if (mf != null)
        {
            Undo.RecordObject(mf, "Assign Baked Denier Mesh");
            mf.sharedMesh = copy;
            EditorUtility.SetDirty(mf);
        }

        Debug.Log($"[DenierBaker] The mesh could not store vertex colors in place, " +
                  $"so a copy was saved to '{newPath}' and assigned to this object.", this);
        return copy;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Legs
    // ══════════════════════════════════════════════════════════════════════════

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

    /// <summary>Gives every vertex a leg index.</summary>
    private int[] AssignLegs(
        float[] h, float[] s, int[] component, int componentCount,
        out int legCount, out string info)
    {
        int vertCount = h.Length;
        int[] leg = new int[vertCount];

        if (legLayout == DenierLegLayout.SingleLeg)
        {
            legCount = 1;
            info = "single leg";
            return leg;
        }

        // Count the mesh islands that are big enough to be a leg.
        int[] sizes = new int[componentCount];
        for (int i = 0; i < vertCount; i++) sizes[component[i]]++;

        int bigIslands = 0;
        for (int c = 0; c < componentCount; c++)
            if (sizes[c] >= vertCount * 0.05f) bigIslands++;

        if (legLayout == DenierLegLayout.Auto && bigIslands >= 2)
        {
            for (int i = 0; i < vertCount; i++) leg[i] = component[i];
            legCount = componentCount;
            info = "one per mesh island";
            return leg;
        }

        // One island: look for a gap between the two feet.
        float minH = float.MaxValue, maxH = float.MinValue;
        float minS = float.MaxValue, maxS = float.MinValue;
        for (int i = 0; i < vertCount; i++)
        {
            if (h[i] < minH) minH = h[i];
            if (h[i] > maxH) maxH = h[i];
            if (s[i] < minS) minS = s[i];
            if (s[i] > maxS) maxS = s[i];
        }

        float lowBand = minH + (maxH - minH) * 0.15f;
        List<float> low = new List<float>();
        for (int i = 0; i < vertCount; i++)
            if (h[i] <= lowBand) low.Add(s[i]);
        low.Sort();

        float bestGap = 0f;
        float split = (minS + maxS) * 0.5f;
        for (int i = 1; i < low.Count; i++)
        {
            float gap = low[i] - low[i - 1];
            if (gap > bestGap)
            {
                bestGap = gap;
                split = (low[i] + low[i - 1]) * 0.5f;
            }
        }

        bool twoLegs = legLayout == DenierLegLayout.TwoLegs
                       || bestGap > (maxS - minS) * 0.1f;
        if (!twoLegs)
        {
            legCount = 1;
            info = "single leg";
            return leg;
        }

        for (int i = 0; i < vertCount; i++) leg[i] = s[i] >= split ? 1 : 0;
        legCount = 2;
        info = "split down the middle";
        return leg;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Welt
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Distance in metres from the top open edge of each mesh island.
    /// Indexed by canonical vertex. Islands without an open edge keep
    /// float.MaxValue.
    /// </summary>
    private static float[] ComputeWeltDistance(
        Vector3[] positions, float scale, int[] tris, int[] canon,
        int[] component, int componentCount, float[] h,
        out int weltLoopCount, out List<int>[] weltSegmentsOut)
    {
        int vertCount = positions.Length;

        // An edge used by exactly one triangle is an open edge.
        var edgeUse = new Dictionary<long, int>();
        for (int t = 0; t < tris.Length; t += 3)
        {
            int a = canon[tris[t]];
            int b = canon[tris[t + 1]];
            int c = canon[tris[t + 2]];
            CountEdge(edgeUse, a, b);
            CountEdge(edgeUse, b, c);
            CountEdge(edgeUse, c, a);
        }

        // Join open edges into loops.
        int[] loopParent = new int[vertCount];
        for (int i = 0; i < vertCount; i++) loopParent[i] = i;
        bool[] onBoundary = new bool[vertCount];

        foreach (KeyValuePair<long, int> kv in edgeUse)
        {
            if (kv.Value != 1) continue;
            int a = (int)(kv.Key >> 32);
            int b = (int)(kv.Key & 0xFFFFFFFFL);
            onBoundary[a] = true;
            onBoundary[b] = true;
            Union(loopParent, a, b);
        }

        // Average height of each loop.
        var loopSum = new Dictionary<int, float>();
        var loopCount = new Dictionary<int, int>();
        for (int i = 0; i < vertCount; i++)
        {
            if (!onBoundary[i]) continue;
            int root = Find(loopParent, i);
            loopSum.TryGetValue(root, out float sum);
            loopCount.TryGetValue(root, out int count);
            loopSum[root] = sum + h[i];
            loopCount[root] = count + 1;
        }

        // The highest loop of each island is its welt edge.
        int[] bestLoop = new int[componentCount];
        float[] bestHeight = new float[componentCount];
        for (int c = 0; c < componentCount; c++) { bestLoop[c] = -1; bestHeight[c] = float.MinValue; }

        foreach (KeyValuePair<int, float> kv in loopSum)
        {
            int root = kv.Key;
            float mean = kv.Value / loopCount[root];
            int c = component[root];
            if (mean > bestHeight[c])
            {
                bestHeight[c] = mean;
                bestLoop[c] = root;
            }
        }

        weltLoopCount = 0;
        for (int c = 0; c < componentCount; c++)
            if (bestLoop[c] >= 0) weltLoopCount++;

        // Collect the welt edge of every island as line segments.
        var weltSegments = new List<int>[componentCount];
        for (int c = 0; c < componentCount; c++) weltSegments[c] = new List<int>();

        foreach (KeyValuePair<long, int> kv in edgeUse)
        {
            if (kv.Value != 1) continue;
            int a = (int)(kv.Key >> 32);
            int b = (int)(kv.Key & 0xFFFFFFFFL);
            int c = component[a];
            if (Find(loopParent, a) != bestLoop[c]) continue;
            weltSegments[c].Add(a);
            weltSegments[c].Add(b);
        }

        // Straight-line distance from every vertex to the nearest point on its
        // island's welt edge. Following mesh edges instead would zigzag and
        // give the band a ragged lower border.
        float[] dist = new float[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            dist[i] = float.MaxValue;
            if (canon[i] != i) continue;

            List<int> segments = weltSegments[component[i]];
            float best = float.MaxValue;
            for (int k = 0; k < segments.Count; k += 2)
            {
                float d = PointSegmentDistance(
                    positions[i], positions[segments[k]], positions[segments[k + 1]]);
                if (d < best) best = d;
            }

            if (best != float.MaxValue) dist[i] = best * scale;
        }

        weltSegmentsOut = weltSegments;
        return dist;
    }

    private static float PointSegmentDistance(Vector3 p, Vector3 a, Vector3 b)
    {
        Vector3 ab = b - a;
        float lengthSq = ab.sqrMagnitude;
        float t = lengthSq > 1e-12f ? Mathf.Clamp01(Vector3.Dot(p - a, ab) / lengthSq) : 0f;
        return (p - (a + ab * t)).magnitude;
    }

    private static void CountEdge(Dictionary<long, int> edgeUse, int a, int b)
    {
        if (a == b) return;
        long lo = Mathf.Min(a, b);
        long hi = Mathf.Max(a, b);
        long key = (lo << 32) | hi;
        edgeUse.TryGetValue(key, out int n);
        edgeUse[key] = n + 1;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Stretch
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Slices each leg along its height and compares the radius of every slice
    /// with the narrowest slice above the foot (the ankle). The foot itself is
    /// treated as relaxed, because a horizontal slice through a foot is not a
    /// circumference.
    /// </summary>
    private bool TryBuildCircumferenceMetric(
        float[] h, float[] f, float[] s, int[] leg, int legCount,
        float[] legMinH, float[] legMaxH, float[] footMask,
        out float[] ratio, out string failureReason)
    {
        ratio = null;
        failureReason = string.Empty;

        int vertCount = h.Length;
        int sliceCount = Mathf.Max(8, syntheticSliceCount);
        int bucketCount = legCount * sliceCount;

        int[] bucket = new int[vertCount];
        float[] sumF = new float[bucketCount];
        float[] sumS = new float[bucketCount];
        int[] counts = new int[bucketCount];

        for (int i = 0; i < vertCount; i++)
        {
            int l = leg[i];
            float range = Mathf.Max(legMaxH[l] - legMinH[l], 1e-6f);
            float t = Mathf.Clamp01((h[i] - legMinH[l]) / range);
            int slice = Mathf.Clamp(Mathf.FloorToInt(t * sliceCount), 0, sliceCount - 1);
            int b = l * sliceCount + slice;
            bucket[i] = b;
            sumF[b] += f[i];
            sumS[b] += s[i];
            counts[b]++;
        }

        float[] radiusSum = new float[bucketCount];
        for (int i = 0; i < vertCount; i++)
        {
            int b = bucket[i];
            float cf = sumF[b] / counts[b];
            float cs = sumS[b] / counts[b];
            float df = f[i] - cf;
            float ds = s[i] - cs;
            radiusSum[b] += Mathf.Sqrt(df * df + ds * ds);
        }

        float[] avgRadius = new float[bucketCount];
        float[] ankleRadius = new float[legCount];
        for (int l = 0; l < legCount; l++) ankleRadius[l] = float.MaxValue;

        for (int b = 0; b < bucketCount; b++)
        {
            if (counts[b] == 0) continue;
            avgRadius[b] = radiusSum[b] / counts[b];

            int l = b / sliceCount;
            int slice = b % sliceCount;
            float range = legMaxH[l] - legMinH[l];
            float sliceBottom = range * slice / sliceCount;

            // Only slices above the foot can be the ankle.
            if (sliceBottom < footHeight) continue;
            if (avgRadius[b] > 1e-6f && avgRadius[b] < ankleRadius[l])
                ankleRadius[l] = avgRadius[b];
        }

        bool any = false;
        for (int l = 0; l < legCount; l++)
            if (ankleRadius[l] != float.MaxValue) any = true;

        if (!any)
        {
            failureReason = "No leg slices were found above the foot. Check the Up Axis " +
                            "and Metres Per Mesh Unit.";
            return false;
        }

        ratio = new float[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            int l = leg[i];
            if (ankleRadius[l] == float.MaxValue)
            {
                ratio[i] = 1f;
                continue;
            }

            float r = avgRadius[bucket[i]] / ankleRadius[l];
            ratio[i] = Mathf.Lerp(r, 1f, footMask[i]);
        }

        return true;
    }

    private static bool TryBuildAreaStretchMetric(
        Mesh currentMesh,
        Mesh referenceMesh,
        out float[] areaStretchMetric,
        out string failureReason)
    {
        areaStretchMetric = null;
        failureReason = string.Empty;

        if (referenceMesh == null)
        {
            failureReason = "No reference rest mesh assigned.";
            return false;
        }

        if (currentMesh.vertexCount != referenceMesh.vertexCount)
        {
            failureReason = "Vertex count does not match the reference mesh.";
            return false;
        }

        int[] currTris = currentMesh.triangles;
        int[] refTris = referenceMesh.triangles;

        if (currTris.Length != refTris.Length)
        {
            failureReason = "Triangle count does not match the reference mesh.";
            return false;
        }

        for (int i = 0; i < currTris.Length; i++)
        {
            if (currTris[i] != refTris[i])
            {
                failureReason = "Triangle topology does not match the reference mesh.";
                return false;
            }
        }

        Vector3[] currVerts = currentMesh.vertices;
        Vector3[] refVerts = referenceMesh.vertices;
        int vertCount = currVerts.Length;

        float[] currAreas = new float[vertCount];
        float[] refAreas = new float[vertCount];

        for (int t = 0; t < currTris.Length; t += 3)
        {
            int ia = currTris[t];
            int ib = currTris[t + 1];
            int ic = currTris[t + 2];

            float currArea = TriangleArea(currVerts[ia], currVerts[ib], currVerts[ic]) / 3f;
            float refArea = TriangleArea(refVerts[ia], refVerts[ib], refVerts[ic]) / 3f;

            currAreas[ia] += currArea;
            currAreas[ib] += currArea;
            currAreas[ic] += currArea;

            refAreas[ia] += refArea;
            refAreas[ib] += refArea;
            refAreas[ic] += refArea;
        }

        areaStretchMetric = new float[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            float areaStretch = currAreas[i] / Mathf.Max(refAreas[i], 1e-8f);
            areaStretchMetric[i] = areaStretch;
        }

        return true;
    }

    private static float TriangleArea(Vector3 a, Vector3 b, Vector3 c)
    {
        return Vector3.Cross(b - a, c - a).magnitude * 0.5f;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Topology helpers
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Maps every vertex to the first vertex at the same position, so UV-seam
    /// splits count as one vertex.
    /// </summary>
    private static int[] BuildCanonicalIndices(Vector3[] positions)
    {
        int vertCount = positions.Length;
        var posToCanon = new Dictionary<Vector3, int>(vertCount, new Vector3EqComparer());
        int[] canon = new int[vertCount];

        for (int i = 0; i < vertCount; i++)
        {
            if (!posToCanon.TryGetValue(positions[i], out int c))
            {
                c = i;
                posToCanon[positions[i]] = c;
            }
            canon[i] = c;
        }

        return canon;
    }

    /// <summary>Edge neighbours on welded vertices. Only canonical slots are filled.</summary>
    private static HashSet<int>[] BuildCanonicalAdjacency(int vertCount, int[] tris, int[] canon)
    {
        var canonAdj = new HashSet<int>[vertCount];
        for (int i = 0; i < vertCount; i++) canonAdj[i] = new HashSet<int>();

        for (int t = 0; t < tris.Length; t += 3)
        {
            int a = canon[tris[t]];
            int b = canon[tris[t + 1]];
            int c = canon[tris[t + 2]];

            if (a != b) { canonAdj[a].Add(b); canonAdj[b].Add(a); }
            if (b != c) { canonAdj[b].Add(c); canonAdj[c].Add(b); }
            if (c != a) { canonAdj[c].Add(a); canonAdj[a].Add(c); }
        }

        return canonAdj;
    }

    /// <summary>
    /// Expands welded adjacency back to every split vertex, so smoothing
    /// crosses UV seams.
    /// </summary>
    private static List<int>[] ExpandAdjacency(HashSet<int>[] canonAdj, int[] canon)
    {
        int vertCount = canon.Length;

        var canonToAll = new List<int>[vertCount];
        for (int i = 0; i < vertCount; i++) canonToAll[i] = new List<int>();
        for (int i = 0; i < vertCount; i++) canonToAll[canon[i]].Add(i);

        var adj = new List<int>[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            adj[i] = new List<int>();
            foreach (int cNeighbour in canonAdj[canon[i]])
            {
                foreach (int realNeighbour in canonToAll[cNeighbour])
                    if (realNeighbour != i)
                        adj[i].Add(realNeighbour);
            }
        }

        return adj;
    }

    /// <summary>Labels connected mesh islands 0..componentCount-1 for every vertex.</summary>
    private static int[] BuildComponents(int vertCount, int[] tris, int[] canon, out int componentCount)
    {
        int[] parent = new int[vertCount];
        for (int i = 0; i < vertCount; i++) parent[i] = i;

        for (int t = 0; t < tris.Length; t += 3)
        {
            int a = canon[tris[t]];
            Union(parent, a, canon[tris[t + 1]]);
            Union(parent, a, canon[tris[t + 2]]);
        }

        var rootToId = new Dictionary<int, int>();
        int[] component = new int[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            int root = Find(parent, canon[i]);
            if (!rootToId.TryGetValue(root, out int id))
            {
                id = rootToId.Count;
                rootToId[root] = id;
            }
            component[i] = id;
        }

        componentCount = rootToId.Count;
        return component;
    }

    private static int Find(int[] parent, int i)
    {
        while (parent[i] != i)
        {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    }

    private static void Union(int[] parent, int a, int b)
    {
        int ra = Find(parent, a);
        int rb = Find(parent, b);
        if (ra != rb) parent[ra] = rb;
    }

    /// <summary>One pass of adjacency-weighted smoothing.</summary>
    private static void SmoothOnGraph(float[] values, List<int>[] adj)
    {
        int     n    = values.Length;
        float[] copy = new float[n];

        for (int i = 0; i < n; i++)
        {
            List<int> nb = adj[i];
            if (nb.Count == 0)
            {
                copy[i] = values[i];
                continue;
            }

            // Centre weight 0.5, neighbours share the remaining 0.5
            float sum = values[i] * 0.5f;
            float wNb = 0.5f / nb.Count;
            foreach (int j in nb) sum += values[j] * wNb;
            copy[i] = sum;
        }

        for (int i = 0; i < n; i++) values[i] = copy[i];
    }

    // Equality comparer that snaps positions to a small grid to tolerate
    // floating-point jitter from mesh subdivision.
    private class Vector3EqComparer : IEqualityComparer<Vector3>
    {
        private const float SnapGrid = 0.0001f;
        public bool Equals(Vector3 a, Vector3 b)
            => SnapF(a.x) == SnapF(b.x) && SnapF(a.y) == SnapF(b.y) && SnapF(a.z) == SnapF(b.z);
        public int GetHashCode(Vector3 v)
        {
            int hx = SnapF(v.x).GetHashCode();
            int hy = SnapF(v.y).GetHashCode();
            int hz = SnapF(v.z).GetHashCode();
            return hx ^ (hy << 5) ^ (hz << 10);
        }
        private static float SnapF(float f) => Mathf.Round(f / SnapGrid) * SnapGrid;
    }

#endif // UNITY_EDITOR
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Inspector
// ══════════════════════════════════════════════════════════════════════════════
#if UNITY_EDITOR
[CustomEditor(typeof(PantyhoseDenierBaker))]
public class PantyhoseDenierBakerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        // Draw all serialized fields as normal
        DrawDefaultInspector();

        EditorGUILayout.Space(8);

        PantyhoseDenierBaker baker = (PantyhoseDenierBaker)target;

        // Warm amber button that stands out from the default grey
        Color prevBg = GUI.backgroundColor;
        GUI.backgroundColor = new Color(1f, 0.78f, 0.3f);

        if (GUILayout.Button("▶  Bake Denier Vertex Colors", GUILayout.Height(32)))
        {
            baker.BakeDenierVertexColors();
        }

        GUI.backgroundColor = prevBg;

        string helpMsg =
            "R channel: dense zones (welt, heel, toe). Enable 'Vertex Red = Dense Zone' on the material.\n" +
            "G channel: stretch. Enable 'Vertex Green = Stretch' on the material.\n" +
            "A mesh inside a model file is copied to a .asset next to it so the result is kept.";

        if (baker.stretchMode == DenierStretchMode.ReferenceAreaStretch)
            helpMsg += "\nStretch: Reference Area. Assign a rest mesh with matching topology.";
        else if (baker.stretchMode == DenierStretchMode.SyntheticCircumferenceStretch)
            helpMsg += "\nStretch: Synthetic Circumference. Leg radius compared with the ankle.";
        else
            helpMsg += "\nStretch: None. G is written as 0.";

        EditorGUILayout.HelpBox(helpMsg, MessageType.Info);
    }
}
#endif // UNITY_EDITOR
