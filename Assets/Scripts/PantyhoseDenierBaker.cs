using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// Bakes per-vertex denier (fabric density/opacity) into the Red channel of mesh vertex colors.
///
/// HOW IT WORKS
/// ─────────────
/// Uses per-vertex normal divergence to detect anatomical pinch points:
///
///   For each vertex, the average angle between its own normal and the normals of
///   all its edge-connected neighbours is computed.
///
///   High divergence (normals change quickly)  → surface is curving sharply
///                                             → anatomical pinch (ankle, knee)
///                                             → fabric is dense → bright R
///
///   Low divergence  (normals barely change)   → surface is flat/cylindrical
///                                             → calf, thigh
///                                             → fabric is sheer → dark R
///
/// This approach requires no limb-axis assumption and works correctly
/// on any leg orientation or pose.
///
/// SHADER SETUP
/// ─────────────
/// On the FabricPBR_ProceduralPattern material:
///     ✔  Enable "Vertex Red = Denier Opacity" (_UseDenierFromVertexR)
///     •  Sheer Area Opacity (R=0)  →  opacity at flat zones  (e.g. 0.0)
///     •  Dense zones (R=1)         →  always fully opaque    (hardcoded 1.0)
///
/// USAGE
/// ──────
/// 1. Add this component to the leg mesh GameObject.
/// 2. Tune the fields below.
/// 3. Click "▶ Bake Denier Vertex Colors" in the Inspector.
/// </summary>
[RequireComponent(typeof(MeshFilter))]
public class PantyhoseDenierBaker : MonoBehaviour
{
    // ─── Denier Range ─────────────────────────────────────────────────────────
    [Header("Denier Range")]
    [Tooltip("R written at high-curvature areas (ankle, knee).\n" +
             "Should be HIGH (e.g. 1.0) = dense / opaque.")]
    [Range(0f, 1f)]
    public float denierAtNarrowest = 1.0f;

    [Tooltip("R written at low-curvature areas (calf, thigh).\n" +
             "Should be LOW (e.g. 0.0) = sheer / transparent.")]
    [Range(0f, 1f)]
    public float denierAtWidest = 0.0f;

    [Tooltip("Power curve applied after normalisation.\n" +
             "Values > 1 sharpen ankle/knee peaks and flatten calf/thigh further.\n" +
             "1 = linear.  2–4 recommended.")]
    [Range(0.1f, 5f)]
    public float contrastPower = 2.5f;

    // ─── Smoothing ────────────────────────────────────────────────────────────
    [Header("Smoothing")]
    [Tooltip("How many adjacency-weighted smoothing passes to run over the\n" +
             "raw per-vertex divergence values.\n" +
             "0 = raw (noisy).  4–8 = smooth, wide transition zone.")]
    [Range(0, 16)]
    public int smoothingPasses = 6;

    // ─── Stretch (Green channel) ──────────────────────────────────────────────
    [Header("Stretch (Green Channel)")]
    [Tooltip("When enabled, the Green channel is written as the inverse of Red,\n" +
             "so sheer areas (R=0) get high stretch (G≈1) and dense areas\n" +
             "(R=1) get low stretch (G≈0).\n\n" +
             "Enable '_UseStretchFromVertexG' on the material to use this.")]
    public bool bakeStretchFromDenier = true;

    [Tooltip("Power curve applied to the inverted R before writing G.\n" +
             "1 = linear inverse.  >1 = stretch concentrates more in sheer areas.\n" +
             "<1 = stretch spreads more evenly.")]
    [Range(0.2f, 5f)]
    public float stretchContrastPower = 1.5f;

    [Tooltip("Maximum stretch value written to G (at R=0, fully sheer).\n" +
             "1.0 = full stretch.  Lower values limit how much the openings grow.")]
    [Range(0f, 1f)]
    public float maxStretch = 0.85f;

    [Tooltip("Minimum stretch value written to G (at R=1, fully dense).\n" +
             "0.0 = no stretch.  Raise slightly if you want some stretch everywhere.")]
    [Range(0f, 1f)]
    public float minStretch = 0.0f;

#if UNITY_EDITOR

    // ══════════════════════════════════════════════════════════════════════════
    // Entry Point
    // ══════════════════════════════════════════════════════════════════════════

    [ContextMenu("Bake Denier Vertex Colors")]
    public void BakeDenierVertexColors()
    {
        MeshFilter mf = GetComponent<MeshFilter>();
        Mesh sourceMesh = mf.sharedMesh;

        if (sourceMesh == null)
        {
            Debug.LogError("[DenierBaker] No mesh found on MeshFilter.", this);
            return;
        }

        Vector3[] vertices  = sourceMesh.vertices;
        Vector3[] normals   = sourceMesh.normals;
        int[]     triangles = sourceMesh.triangles;
        int       vertCount = vertices.Length;

        if (vertCount == 0 || normals.Length != vertCount)
        {
            Debug.LogError("[DenierBaker] Mesh has no vertices or normals.", this);
            return;
        }

        // ── Step 1: build adjacency list (vertices sharing an edge) ──────────
        // We use welded positions because imported meshes often split verts at
        // UV seams – sharing the same position but different normals. We weld
        // them first so adjacency crosses seams correctly.
        List<int>[] adj = BuildAdjacency(vertCount, triangles, vertices);

        // ── Step 2: per-vertex normal divergence ──────────────────────────────
        // divergence[i] = average angle (radians) between vertex i's normal
        // and each of its neighbours' normals.
        float[] divergence = new float[vertCount];

        for (int i = 0; i < vertCount; i++)
        {
            List<int> neighbours = adj[i];
            if (neighbours.Count == 0)
            {
                divergence[i] = 0f;
                continue;
            }

            float sumAngle = 0f;
            Vector3 ni = normals[i];

            foreach (int j in neighbours)
            {
                float dot   = Mathf.Clamp(Vector3.Dot(ni, normals[j]), -1f, 1f);
                sumAngle   += Mathf.Acos(dot); // radians in [0, π]
            }

            divergence[i] = sumAngle / neighbours.Count;
        }

        // ── Step 3: adjacency-weighted smoothing ──────────────────────────────
        for (int pass = 0; pass < smoothingPasses; pass++)
            SmoothOnGraph(divergence, adj);

        // ── Step 4: normalise to [0, 1] ───────────────────────────────────────
        float minD = float.MaxValue, maxD = float.MinValue;
        for (int i = 0; i < vertCount; i++)
        {
            if (divergence[i] < minD) minD = divergence[i];
            if (divergence[i] > maxD) maxD = divergence[i];
        }

        float divRange = maxD - minD;
        if (divRange < 1e-6f)
        {
            Debug.LogWarning(
                "[DenierBaker] Normal divergence signal is flat. " +
                "The mesh may not have meaningful curvature variation.", this);
        }

        // ── Step 5: build Color array ─────────────────────────────────────────
        Color[] existingColors = sourceMesh.colors;
        bool    hasColors      = existingColors != null && existingColors.Length == vertCount;
        Color[] newColors      = new Color[vertCount];

        for (int i = 0; i < vertCount; i++)
        {
            Color prev = hasColors ? existingColors[i] : new Color(0f, 0f, 0f, 1f);

            float norm = (divRange > 1e-6f) ? (divergence[i] - minD) / divRange : 0f;

            // Power curve: sharpens high-curvature peaks, suppresses flat zones
            float curved = Mathf.Pow(norm, contrastPower);

            // High divergence (ankle/knee) → denierAtNarrowest (bright)
            // Low  divergence (calf/thigh) → denierAtWidest    (dark)
            float r = Mathf.Lerp(denierAtWidest, denierAtNarrowest, curved);

            // Green channel: stretch from inverted denier
            // R=0 (sheer/flat) → G=maxStretch (large openings)
            // R=1 (dense/pinch) → G=minStretch (tight weave)
            float g = prev.g;
            if (bakeStretchFromDenier)
            {
                float invR = 1f - r;
                float stretchCurved = Mathf.Pow(invR, stretchContrastPower);
                g = Mathf.Lerp(minStretch, maxStretch, stretchCurved);
            }

            newColors[i] = new Color(r, g, prev.b, prev.a);
        }

        // ── Step 6: write to mesh ─────────────────────────────────────────────
        Undo.RecordObject(sourceMesh, "Bake Denier Vertex Colors");
        sourceMesh.colors = newColors;
        EditorUtility.SetDirty(sourceMesh);

        Debug.Log(
            $"[DenierBaker] Done. Normal-divergence bake on '{sourceMesh.name}'. " +
            $"Smoothing passes: {smoothingPasses}, Contrast power: {contrastPower}.",
            this);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ══════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Builds a per-vertex adjacency list.
    /// Welds vertices at the same world position so UV-seam splits
    /// don't break adjacency across the seam.
    /// </summary>
    private static List<int>[] BuildAdjacency(int vertCount, int[] tris, Vector3[] positions)
    {
        // Map each unique position → canonical vertex index
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

        // Build adjacency on canonical indices, then mirror back to all splits
        var canonAdj = new HashSet<int>[vertCount];
        for (int i = 0; i < vertCount; i++) canonAdj[i] = new HashSet<int>();

        for (int t = 0; t < tris.Length; t += 3)
        {
            int a = canon[tris[t]];
            int b = canon[tris[t + 1]];
            int c = canon[tris[t + 2]];

            canonAdj[a].Add(b); canonAdj[a].Add(c);
            canonAdj[b].Add(a); canonAdj[b].Add(c);
            canonAdj[c].Add(a); canonAdj[c].Add(b);
        }

        // Expand canonical adjacency back to split-vertex adjacency
        // (so seam vertices share the normal-space neighbours of their weld-twin)
        var adj = new List<int>[vertCount];
        for (int i = 0; i < vertCount; i++) adj[i] = new List<int>();

        // cache: for each canonical index, which real indices map to it?
        var canonToAll = new List<int>[vertCount];
        for (int i = 0; i < vertCount; i++) canonToAll[i] = new List<int>();
        for (int i = 0; i < vertCount; i++) canonToAll[canon[i]].Add(i);

        for (int i = 0; i < vertCount; i++)
        {
            foreach (int cNeighbour in canonAdj[canon[i]])
            {
                foreach (int realNeighbour in canonToAll[cNeighbour])
                    if (realNeighbour != i)
                        adj[i].Add(realNeighbour);
            }
        }

        return adj;
    }

    /// <summary>One pass of adjacency-weighted (graph) Gaussian smoothing.</summary>
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

        // Small hint label
        string helpMsg = "Writes vertex colors directly onto the mesh in-place (no asset copy created).\n" +
            "R channel: denier (density) — enable '_UseDenierFromVertexR' on the material.";
        if (baker.bakeStretchFromDenier)
            helpMsg += "\nG channel: stretch (inverted denier) — enable '_UseStretchFromVertexG' on the material.";
        EditorGUILayout.HelpBox(helpMsg, MessageType.Info);
    }
}
#endif // UNITY_EDITOR
