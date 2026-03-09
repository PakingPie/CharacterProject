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
/// Two bake modes are supported:
///
/// 1. Reference Area Stretch (more physical)
///    Compares the current mesh against a rest/reference mesh with identical
///    topology. Local triangle-area stretch is measured per vertex and mapped
///    through fixed calibration thresholds.
///
///    Low area stretch   -> fabric stays dense -> bright R
///    High area stretch  -> fabric thins out -> sheer -> dark R
///
///    Unlike the older implementation, this mode no longer normalises the
///    current pose to its own min/max. That keeps the result interpretable
///    across poses instead of expanding tiny changes into the full 0..1 range.
///
/// 2. Synthetic Circumference Stretch (practical for body-derived stockings)
///    Uses the current mesh only. Each leg is sliced horizontally and local
///    cross-section radius is compared against the narrowest slice radius.
///
///    Wider regions       -> more synthetic stretch -> lower denier -> dark R
///    Narrower regions    -> less synthetic stretch -> higher denier -> bright R
///
///    This is not a true physical rest-garment simulation, but it works well
///    when the stocking mesh was derived from the leg surface itself.
///
/// 3. Curvature Proxy (fallback / heuristic)
///    Uses per-vertex normal divergence to detect anatomical pinch points:
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
public enum DenierBakeMode
{
    ReferenceAreaStretch,
    SyntheticCircumferenceStretch,
    CurvatureProxy
}

[RequireComponent(typeof(MeshFilter))]
public class PantyhoseDenierBaker : MonoBehaviour
{
    // ─── Bake Source ─────────────────────────────────────────────────────────
    [Header("Bake Source")]
    [Tooltip("Reference Area Stretch is more physical: it compares the current mesh\n" +
             "against a rest mesh with identical topology and bakes inverse local\n" +
             "area stretch as denier. Curvature Proxy keeps the older heuristic.")]
    public DenierBakeMode bakeMode = DenierBakeMode.ReferenceAreaStretch;

    [Tooltip("Rest/reference mesh with the same vertex and triangle topology as\n" +
             "the current mesh. Used only in Reference Area Stretch mode.")]
    public Mesh referenceRestMesh;

    [Header("Synthetic Stretch Source")]
    [Tooltip("Number of horizontal Y slices used to estimate local leg width\n" +
             "for Synthetic Circumference Stretch mode.")]
    [Range(8, 256)]
    public int syntheticSliceCount = 48;

    [Tooltip("Scale applied to the narrowest slice radius when constructing the\n" +
             "synthetic unstretched rest state. 1 = narrowest slice is treated as\n" +
             "dense/rest. Values below 1 assume an even smaller unstretched garment\n" +
             "and therefore produce more stretch overall.")]
    [Range(0.5f, 1.2f)]
    public float syntheticRestScale = 1.0f;

    [Header("Reference Stretch Calibration")]
    [Tooltip("Area-stretch ratio treated as dense / opaque.\n" +
             "1.0 means the same local surface area as the rest mesh.")]
    [Min(0.01f)]
    public float areaStretchAtDense = 1.0f;

    [Tooltip("Area-stretch ratio treated as sheer / transparent.\n" +
             "Values at or above this clamp to denierAtWidest.")]
    [Min(0.01f)]
    public float areaStretchAtSheer = 1.25f;

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
    [Tooltip("When enabled, the Green channel is written for the shader's\n" +
             "stretch/opening control. In Reference Area Stretch mode, G stores\n" +
             "the calibrated measured stretch directly. In Curvature Proxy mode,\n" +
             "G falls back to inverse denier.\n\n" +
             "Enable '_UseStretchFromVertexG' on the material to use this.")]
    public bool bakeStretchFromDenier = true;

    [Tooltip("Power curve applied before writing G.\n" +
             "In Reference Area Stretch mode it shapes the measured stretch.\n" +
             "In Curvature Proxy mode it shapes the inverse-denier fallback.\n" +
             "1 = linear.  >1 = stretch concentrates more in high-stretch areas.")]
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

        // ── Step 2: build density metric ──────────────────────────────────────
        float[] densityMetric;
        string metricName;
        bool useCalibratedStretchMetric = false;

        if (bakeMode == DenierBakeMode.ReferenceAreaStretch)
        {
            if (!TryBuildAreaStretchMetric(sourceMesh, referenceRestMesh,
                out densityMetric, out string failureReason))
            {
                Debug.LogWarning(
                    "[DenierBaker] Reference Area Stretch mode could not be used: " +
                    failureReason + " Falling back to Curvature Proxy.", this);

                densityMetric = ComputeNormalDivergenceMetric(normals, adj);
                metricName = "curvature-proxy";
            }
            else
            {
                metricName = "reference-area-stretch";
                useCalibratedStretchMetric = true;
            }
        }
        else if (bakeMode == DenierBakeMode.SyntheticCircumferenceStretch)
        {
            if (!TryBuildSyntheticCircumferenceStretchMetric(vertices,
                out densityMetric, out string failureReason))
            {
                Debug.LogWarning(
                    "[DenierBaker] Synthetic Circumference Stretch mode could not be used: " +
                    failureReason + " Falling back to Curvature Proxy.", this);

                densityMetric = ComputeNormalDivergenceMetric(normals, adj);
                metricName = "curvature-proxy";
            }
            else
            {
                metricName = "synthetic-circumference-stretch";
                useCalibratedStretchMetric = true;
            }
        }
        else
        {
            densityMetric = ComputeNormalDivergenceMetric(normals, adj);
            metricName = "curvature-proxy";
        }

        // ── Step 3: adjacency-weighted smoothing ──────────────────────────────
        for (int pass = 0; pass < smoothingPasses; pass++)
            SmoothOnGraph(densityMetric, adj);

        // ── Step 4: gather metric range ───────────────────────────────────────
        float minD = float.MaxValue, maxD = float.MinValue;
        for (int i = 0; i < vertCount; i++)
        {
            if (densityMetric[i] < minD) minD = densityMetric[i];
            if (densityMetric[i] > maxD) maxD = densityMetric[i];
        }

        float divRange = maxD - minD;
        if (!useCalibratedStretchMetric && divRange < 1e-6f)
        {
            Debug.LogWarning(
                "[DenierBaker] Density signal is flat. " +
                "The mesh may not have meaningful curvature variation.", this);
        }

        // ── Step 5: build Color array ─────────────────────────────────────────
        Color[] existingColors = sourceMesh.colors;
        bool    hasColors      = existingColors != null && existingColors.Length == vertCount;
        Color[] newColors      = new Color[vertCount];

        for (int i = 0; i < vertCount; i++)
        {
            Color prev = hasColors ? existingColors[i] : new Color(0f, 0f, 0f, 1f);

            float r;
            float calibratedStretch = 0f;
            if (useCalibratedStretchMetric)
            {
                float denseStretch = Mathf.Max(0.01f, areaStretchAtDense);
                float sheerStretch = Mathf.Max(denseStretch + 1e-4f, areaStretchAtSheer);

                // 0 = dense/rest-like, 1 = fully sheer from stretch.
                calibratedStretch = Mathf.InverseLerp(denseStretch, sheerStretch, densityMetric[i]);
                float curvedSheer = Mathf.Pow(calibratedStretch, contrastPower);
                r = Mathf.Lerp(denierAtNarrowest, denierAtWidest, curvedSheer);
            }
            else
            {
                float norm = (divRange > 1e-6f) ? (densityMetric[i] - minD) / divRange : 0f;

                // Power curve: sharpens high-curvature peaks, suppresses flat zones
                float curved = Mathf.Pow(norm, contrastPower);

                // High divergence (ankle/knee) → denierAtNarrowest (bright)
                // Low  divergence (calf/thigh) → denierAtWidest    (dark)
                r = Mathf.Lerp(denierAtWidest, denierAtNarrowest, curved);
            }

            // Green channel:
            // - Reference Area Stretch mode: measured/calibrated stretch.
            // - Curvature Proxy mode: inverse denier fallback.
            float g = prev.g;
            if (bakeStretchFromDenier)
            {
                float stretchSignal = useCalibratedStretchMetric
                    ? calibratedStretch
                    : 1f - r;
                float stretchCurved = Mathf.Pow(stretchSignal, stretchContrastPower);
                g = Mathf.Lerp(minStretch, maxStretch, stretchCurved);
            }

            newColors[i] = new Color(r, g, prev.b, prev.a);
        }

        // ── Step 6: write to mesh ─────────────────────────────────────────────
        Undo.RecordObject(sourceMesh, "Bake Denier Vertex Colors");
        sourceMesh.colors = newColors;
        EditorUtility.SetDirty(sourceMesh);

        Debug.Log(
            $"[DenierBaker] Done. {metricName} bake on '{sourceMesh.name}'. " +
            $"Smoothing passes: {smoothingPasses}, Contrast power: {contrastPower}, " +
            $"metric range: [{minD:F4}, {maxD:F4}].",
            this);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ══════════════════════════════════════════════════════════════════════════

    private static float[] ComputeNormalDivergenceMetric(Vector3[] normals, List<int>[] adj)
    {
        int vertCount = normals.Length;
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
                float dot = Mathf.Clamp(Vector3.Dot(ni, normals[j]), -1f, 1f);
                sumAngle += Mathf.Acos(dot);
            }

            divergence[i] = sumAngle / neighbours.Count;
        }

        return divergence;
    }

    private bool TryBuildSyntheticCircumferenceStretchMetric(
        Vector3[] positions,
        out float[] circumferenceStretch,
        out string failureReason)
    {
        circumferenceStretch = null;
        failureReason = string.Empty;

        int vertCount = positions.Length;
        if (vertCount == 0)
        {
            failureReason = "Mesh has no vertices.";
            return false;
        }

        int sliceCount = Mathf.Max(8, syntheticSliceCount);

        float minY = float.MaxValue;
        float maxY = float.MinValue;
        float minX = float.MaxValue;
        float maxX = float.MinValue;

        for (int i = 0; i < vertCount; i++)
        {
            Vector3 p = positions[i];
            if (p.y < minY) minY = p.y;
            if (p.y > maxY) maxY = p.y;
            if (p.x < minX) minX = p.x;
            if (p.x > maxX) maxX = p.x;
        }

        float yRange = maxY - minY;
        if (yRange < 1e-6f)
        {
            failureReason = "Mesh has no vertical Y extent for synthetic slicing.";
            return false;
        }

        float centerX = (minX + maxX) * 0.5f;
        int bucketCount = sliceCount * 2;

        float[] sumX = new float[bucketCount];
        float[] sumZ = new float[bucketCount];
        int[] counts = new int[bucketCount];

        for (int i = 0; i < vertCount; i++)
        {
            int bucket = GetSyntheticSliceBucket(positions[i], minY, yRange, centerX, sliceCount);
            sumX[bucket] += positions[i].x;
            sumZ[bucket] += positions[i].z;
            counts[bucket]++;
        }

        Vector2[] centers = new Vector2[bucketCount];
        for (int bucket = 0; bucket < bucketCount; bucket++)
        {
            if (counts[bucket] == 0)
                continue;

            float invCount = 1f / counts[bucket];
            centers[bucket] = new Vector2(sumX[bucket] * invCount, sumZ[bucket] * invCount);
        }

        float[] radiusSum = new float[bucketCount];
        for (int i = 0; i < vertCount; i++)
        {
            int bucket = GetSyntheticSliceBucket(positions[i], minY, yRange, centerX, sliceCount);
            Vector2 dxz = new Vector2(positions[i].x, positions[i].z) - centers[bucket];
            radiusSum[bucket] += dxz.magnitude;
        }

        float[] avgRadius = new float[bucketCount];
        float[] minRadiusPerSide = { float.MaxValue, float.MaxValue };

        for (int bucket = 0; bucket < bucketCount; bucket++)
        {
            if (counts[bucket] == 0)
                continue;

            avgRadius[bucket] = radiusSum[bucket] / counts[bucket];
            if (avgRadius[bucket] <= 1e-6f)
                continue;

            int side = bucket / sliceCount;
            if (avgRadius[bucket] < minRadiusPerSide[side])
                minRadiusPerSide[side] = avgRadius[bucket];
        }

        if (minRadiusPerSide[0] == float.MaxValue && minRadiusPerSide[1] == float.MaxValue)
        {
            failureReason = "Could not determine slice radii for synthetic stretch.";
            return false;
        }

        circumferenceStretch = new float[vertCount];
        for (int i = 0; i < vertCount; i++)
        {
            int bucket = GetSyntheticSliceBucket(positions[i], minY, yRange, centerX, sliceCount);
            int side = bucket / sliceCount;
            float baseRadius = minRadiusPerSide[side];
            if (baseRadius == float.MaxValue)
                baseRadius = minRadiusPerSide[1 - side];

            baseRadius = Mathf.Max(baseRadius * syntheticRestScale, 1e-6f);
            float radius = avgRadius[bucket];
            if (radius <= 1e-6f)
            {
                Vector2 dxz = new Vector2(positions[i].x, positions[i].z) - centers[bucket];
                radius = dxz.magnitude;
            }

            circumferenceStretch[i] = radius / baseRadius;
        }

        return true;
    }

    private static int GetSyntheticSliceBucket(
        Vector3 position,
        float minY,
        float yRange,
        float centerX,
        int sliceCount)
    {
        float y01 = Mathf.Clamp01((position.y - minY) / Mathf.Max(yRange, 1e-6f));
        int slice = Mathf.Clamp(Mathf.FloorToInt(y01 * sliceCount), 0, sliceCount - 1);
        int side = position.x >= centerX ? 1 : 0;
        return side * sliceCount + slice;
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
        if (baker.bakeMode == DenierBakeMode.ReferenceAreaStretch)
            helpMsg += "\nBake mode: Reference Area Stretch — assign a rest mesh with matching topology. " +
                $"Stretch {baker.areaStretchAtDense:F2} stays dense; stretch {baker.areaStretchAtSheer:F2} becomes sheer.";
        else if (baker.bakeMode == DenierBakeMode.SyntheticCircumferenceStretch)
            helpMsg += "\nBake mode: Synthetic Circumference Stretch — estimates stretch from horizontal leg width. " +
                $"Rest scale: {baker.syntheticRestScale:F2}, slices: {baker.syntheticSliceCount}.";
        else
            helpMsg += "\nBake mode: Curvature Proxy — heuristic fallback, not physical thickness.";
        if (baker.bakeStretchFromDenier)
            helpMsg += baker.bakeMode == DenierBakeMode.ReferenceAreaStretch
                ? "\nG channel: calibrated measured stretch — enable '_UseStretchFromVertexG' on the material."
                : "\nG channel: inverse denier fallback — enable '_UseStretchFromVertexG' on the material.";
        EditorGUILayout.HelpBox(helpMsg, MessageType.Info);
    }
}
#endif // UNITY_EDITOR
