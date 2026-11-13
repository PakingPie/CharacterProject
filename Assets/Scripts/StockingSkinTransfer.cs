using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// Turns a static stocking mesh into a skinned mesh that follows the leg.
///
/// A stocking that is a plain mesh (MeshFilter + MeshRenderer) does not bend
/// with the character. This tool copies the bone weights from the body's
/// skinned mesh onto the stocking, so both deform the same way.
///
/// HOW IT WORKS
/// ─────────────
/// For every stocking vertex, the nearest body vertex is found and its bone
/// weights are copied. The stocking is then stored relative to the body's
/// skeleton and rendered with a SkinnedMeshRenderer that uses the body's bones.
///
/// USAGE
/// ──────
/// 1. Make sure the stocking sits correctly on the leg in the Scene view.
/// 2. Add this component to the stocking object (the one with the MeshFilter).
/// 3. Assign the body's SkinnedMeshRenderer (the one that draws the leg).
/// 4. Click "Transfer Skin From Body".
///
/// The result is saved as a new mesh asset next to the original. The original
/// mesh is not changed. The old MeshRenderer is disabled, not deleted.
/// </summary>
public class StockingSkinTransfer : MonoBehaviour
{
    [Tooltip("The SkinnedMeshRenderer that draws the leg under the stocking.")]
    public SkinnedMeshRenderer bodyRenderer;

#if UNITY_EDITOR

    [ContextMenu("Transfer Skin From Body")]
    public void TransferSkinFromBody()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        MeshRenderer meshRenderer = GetComponent<MeshRenderer>();

        if (meshFilter == null || meshFilter.sharedMesh == null)
        {
            Debug.LogError("[SkinTransfer] This object needs a MeshFilter with the stocking mesh.", this);
            return;
        }

        if (bodyRenderer == null || bodyRenderer.sharedMesh == null)
        {
            Debug.LogError("[SkinTransfer] Assign the body's SkinnedMeshRenderer first.", this);
            return;
        }

        Mesh stockingMesh = meshFilter.sharedMesh;
        Mesh bodyMesh = bodyRenderer.sharedMesh;

        BoneWeight[] bodyWeights = bodyMesh.boneWeights;
        Matrix4x4[] bindposes = bodyMesh.bindposes;
        Transform[] bones = bodyRenderer.bones;

        if (bodyWeights.Length != bodyMesh.vertexCount || bindposes.Length == 0
            || bones.Length != bindposes.Length)
        {
            Debug.LogError("[SkinTransfer] The body mesh has no usable bone weights.", this);
            return;
        }

        // Body vertices in world space, in the pose the character is in now.
        Mesh bakedBody = new Mesh();
        bodyRenderer.BakeMesh(bakedBody, true);
        Vector3[] bodyWorld = bakedBody.vertices;
        DestroyImmediate(bakedBody);

        Matrix4x4 bodyToWorld = Matrix4x4.TRS(
            bodyRenderer.transform.position, bodyRenderer.transform.rotation, Vector3.one);
        for (int i = 0; i < bodyWorld.Length; i++)
            bodyWorld[i] = bodyToWorld.MultiplyPoint3x4(bodyWorld[i]);

        // Current bone matrices: rest-pose mesh space → world.
        Matrix4x4[] skinMatrices = new Matrix4x4[bones.Length];
        for (int i = 0; i < bones.Length; i++)
        {
            skinMatrices[i] = bones[i] != null
                ? bones[i].localToWorldMatrix * bindposes[i]
                : Matrix4x4.identity;
        }

        Vector3[] vertices = stockingMesh.vertices;
        Vector3[] normals = stockingMesh.normals;
        Vector4[] tangents = stockingMesh.tangents;
        int vertexCount = vertices.Length;

        bool hasNormals = normals != null && normals.Length == vertexCount;
        bool hasTangents = tangents != null && tangents.Length == vertexCount;

        Matrix4x4 stockingToWorld = transform.localToWorldMatrix;
        Matrix4x4 stockingNormalToWorld = stockingToWorld.inverse.transpose;

        BoneWeight[] newWeights = new BoneWeight[vertexCount];
        float worstDistance = 0f;

        for (int i = 0; i < vertexCount; i++)
        {
            if ((i & 255) == 0)
            {
                EditorUtility.DisplayProgressBar("Transfer Skin",
                    "Matching stocking vertices to the body", (float)i / vertexCount);
            }

            Vector3 worldPos = stockingToWorld.MultiplyPoint3x4(vertices[i]);

            // Nearest body vertex.
            int nearest = 0;
            float bestSq = float.MaxValue;
            for (int j = 0; j < bodyWorld.Length; j++)
            {
                float dSq = (bodyWorld[j] - worldPos).sqrMagnitude;
                if (dSq < bestSq)
                {
                    bestSq = dSq;
                    nearest = j;
                }
            }
            worstDistance = Mathf.Max(worstDistance, Mathf.Sqrt(bestSq));

            BoneWeight weight = bodyWeights[nearest];
            newWeights[i] = weight;

            // Undo the current pose, so the vertex is stored in the body's
            // rest-pose space and skinning puts it back where it is now.
            Matrix4x4 skin = BlendSkinMatrix(skinMatrices, weight);
            Matrix4x4 unskin = skin.inverse;

            vertices[i] = unskin.MultiplyPoint3x4(worldPos);

            if (hasNormals)
            {
                Vector3 worldNormal = stockingNormalToWorld.MultiplyVector(normals[i]);
                normals[i] = skin.transpose.MultiplyVector(worldNormal).normalized;
            }

            if (hasTangents)
            {
                Vector3 worldTangent = stockingToWorld.MultiplyVector(
                    new Vector3(tangents[i].x, tangents[i].y, tangents[i].z));
                Vector3 restTangent = unskin.MultiplyVector(worldTangent).normalized;
                tangents[i] = new Vector4(restTangent.x, restTangent.y, restTangent.z, tangents[i].w);
            }
        }

        EditorUtility.ClearProgressBar();

        // New mesh: a copy of the stocking (UVs, colors, triangles) with the
        // rest-pose positions and the body's skinning data.
        Mesh skinned = Instantiate(stockingMesh);
        skinned.name = stockingMesh.name + "_Skinned";
        skinned.vertices = vertices;
        if (hasNormals) skinned.normals = normals;
        if (hasTangents) skinned.tangents = tangents;
        skinned.boneWeights = newWeights;
        skinned.bindposes = bindposes;
        skinned.RecalculateBounds();

        string folder = "Assets";
        string sourcePath = AssetDatabase.GetAssetPath(stockingMesh);
        if (!string.IsNullOrEmpty(sourcePath) && sourcePath.StartsWith("Assets/"))
        {
            int slash = sourcePath.LastIndexOf('/');
            if (slash > 0) folder = sourcePath.Substring(0, slash);
        }

        string newPath = AssetDatabase.GenerateUniqueAssetPath(folder + "/" + skinned.name + ".asset");
        AssetDatabase.CreateAsset(skinned, newPath);
        AssetDatabase.SaveAssets();

        // Swap the renderer.
        SkinnedMeshRenderer skinnedRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedRenderer == null)
            skinnedRenderer = Undo.AddComponent<SkinnedMeshRenderer>(gameObject);
        else
            Undo.RecordObject(skinnedRenderer, "Transfer Skin From Body");

        skinnedRenderer.sharedMesh = skinned;
        skinnedRenderer.bones = bones;
        skinnedRenderer.rootBone = bodyRenderer.rootBone;
        skinnedRenderer.localBounds = bodyRenderer.localBounds;
        if (meshRenderer != null)
            skinnedRenderer.sharedMaterials = meshRenderer.sharedMaterials;
        EditorUtility.SetDirty(skinnedRenderer);

        if (meshRenderer != null)
        {
            Undo.RecordObject(meshRenderer, "Transfer Skin From Body");
            meshRenderer.enabled = false;
            EditorUtility.SetDirty(meshRenderer);
        }

        Debug.Log(
            $"[SkinTransfer] Done. Saved '{newPath}' and set up a SkinnedMeshRenderer. " +
            $"Largest distance from a stocking vertex to the body: {worstDistance:F4} m. " +
            "The old MeshRenderer is disabled; remove it and the MeshFilter once the result looks right.",
            this);
    }

    /// <summary>Weighted sum of the bone matrices that drive one vertex.</summary>
    private static Matrix4x4 BlendSkinMatrix(Matrix4x4[] skinMatrices, BoneWeight weight)
    {
        Matrix4x4 result = Matrix4x4.zero;
        AddScaled(ref result, skinMatrices[weight.boneIndex0], weight.weight0);
        AddScaled(ref result, skinMatrices[weight.boneIndex1], weight.weight1);
        AddScaled(ref result, skinMatrices[weight.boneIndex2], weight.weight2);
        AddScaled(ref result, skinMatrices[weight.boneIndex3], weight.weight3);
        return result;
    }

    private static void AddScaled(ref Matrix4x4 target, Matrix4x4 source, float scale)
    {
        if (scale == 0f) return;
        for (int i = 0; i < 16; i++)
            target[i] += source[i] * scale;
    }

#endif // UNITY_EDITOR
}

#if UNITY_EDITOR
[CustomEditor(typeof(StockingSkinTransfer))]
public class StockingSkinTransferEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        EditorGUILayout.Space(8);

        StockingSkinTransfer transfer = (StockingSkinTransfer)target;

        Color previous = GUI.backgroundColor;
        GUI.backgroundColor = new Color(1f, 0.78f, 0.3f);

        if (GUILayout.Button("▶  Transfer Skin From Body", GUILayout.Height(32)))
        {
            transfer.TransferSkinFromBody();
        }

        GUI.backgroundColor = previous;

        EditorGUILayout.HelpBox(
            "Copies bone weights from the body onto this stocking so it bends with the leg.\n" +
            "The stocking must already sit correctly on the leg. A new mesh asset is saved; " +
            "the original mesh is not changed.",
            MessageType.Info);
    }
}
#endif // UNITY_EDITOR
