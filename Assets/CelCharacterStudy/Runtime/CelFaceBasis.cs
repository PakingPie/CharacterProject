using UnityEngine;

/// <summary>Per-character face/eye basis for the isolated cel study.</summary>
[ExecuteAlways, DefaultExecutionOrder(10000)]
public sealed class CelFaceBasis : MonoBehaviour
{
    public Transform head;
    public Quaternion headToModel = Quaternion.identity;
    public Vector3 faceOriginInHead;
    public Renderer[] targets;
    [Tooltip("Required by the sampled editor capture path; disabled in Play mode.")]
    public bool forceSkinUpdateForEditorCaptures = true;
    MaterialPropertyBlock block;

    void OnEnable() { Apply(); }
    void LateUpdate() { Apply(); }

    public void Apply()
    {
        if (head == null || targets == null) return;
        if (block == null) block = new MaterialPropertyBlock();
        Quaternion basis = head.rotation * headToModel;
        Vector3 origin = head.TransformPoint(faceOriginInHead);
        foreach (Renderer target in targets)
        {
            if (target == null) continue;
            // Preserve independently controlled eye gaze and other renderer overrides.
            target.GetPropertyBlock(block);
            block.SetVector("_HeadForwardWS", basis * Vector3.forward);
            block.SetVector("_HeadRightWS", basis * Vector3.right);
            block.SetVector("_HeadUpWS", basis * Vector3.up);
            block.SetVector("_FaceOriginWS", origin);
            block.SetVector("_EyeForwardWS", basis * Vector3.forward);
            target.SetPropertyBlock(block);
            var skin = target as SkinnedMeshRenderer;
            if (skin != null)
                skin.forceMatrixRecalculationPerRender = forceSkinUpdateForEditorCaptures && !Application.isPlaying;
        }
    }
}
