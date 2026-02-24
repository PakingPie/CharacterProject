using UnityEditor;
using UnityEngine;
using System;
using System.IO;
[CustomEditor(typeof(SkinSettings))]
public class SkinSettingsEditor : Editor
{
    private const double HUMAN_SKIN_DEFAULT_DIFFUSION_RADIUS_MM = 2.7;

    private double[] _diffusionVariance = { 0.0064, 0.0484, 0.187, 0.567, 1.99, 7.41 };
    private double[] _diffusionWeightsR = { 0.233, 0.100, 0.118, 0.113, 0.358, 0.078 };
    private double[] _diffusionWeightsG = { 0.455, 0.336, 0.198, 0.007, 0.004, 0.000 };
    private double[] _diffusionWeightsB = { 0.649, 0.344, 0.000, 0.007, 0.000, 0.000 };

    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        SkinSettings skinSettings = (SkinSettings)target;

        if (GUILayout.Button("Bake Shadow LUT"))
        {
            BakeCurvatureLUT(skinSettings);
        }

        if (GUILayout.Button("Bake Curvature LUT"))
        {
            BakeShadowLUT(skinSettings);
        }
    }

    private void BakeShadowLUT(SkinSettings skinSettings)
    {
        var path = AssetDatabase.GetAssetPath(skinSettings.ShadowLUT);
        var texture = new Texture2D(skinSettings.LutSize, skinSettings.LutSize, TextureFormat.RGBAFloat, false, true);

        double diffusionRadiusFactor = skinSettings.DiffusionRadiusMM / HUMAN_SKIN_DEFAULT_DIFFUSION_RADIUS_MM;

        double shadowRcpWidthMin = diffusionRadiusFactor / skinSettings.MaxShadowWidthMM;
        double shadowRcpWidthMax = diffusionRadiusFactor / skinSettings.MinShadowWidthMM;
        double shadowScale = (shadowRcpWidthMax - shadowRcpWidthMin) / skinSettings.LutSize;
        double shadowBias = shadowRcpWidthMin + 0.5 * shadowScale;

        double[] rgb = new double[3];
        double[] rgbShadowScattering = new double[3];

        for (int y = 0; y < skinSettings.LutSize; y++)
        {
            for (int x = 0; x < skinSettings.LutSize; x++)
            {
                // Calculate input position relative to the shadow edge, by approximately
                // inverting the transfer function of a disc or Gaussian filter.
                double shadowVal = ((double)x + 0.5) / skinSettings.LutSize;
                double inputPosPenumbraSpace = (Math.Sqrt(shadowVal) - Math.Sqrt(1.0 - shadowVal)) * 0.5 + 0.5;
                double rcpWidth = ((double)y) * shadowScale + shadowBias;

                rgb[0] = 0;
                rgb[1] = 0;
                rgb[2] = 0;

                double integrationScaleMM = skinSettings.MaxIntegrationDistanceMM / skinSettings.MonteCarloIterations;
                double integrationBiasMM = -skinSettings.MaxIntegrationDistanceMM * 0.5 + 0.5 * integrationScaleMM;

                for (var i = 0; i < skinSettings.MonteCarloIterations; i++)
                {
                    double offsetMM = i * integrationScaleMM + integrationBiasMM;
                    SumOfGaussians(offsetMM, rgbShadowScattering);

                    // Use smoothstep as an approximation of the transfer function of a
                    // disc or Gaussian filter.
                    double offsetPenumbraSpace = offsetMM * rcpWidth;
                    double newPosPenumbraSpace = (inputPosPenumbraSpace + offsetPenumbraSpace) * skinSettings.ShadowSharpening +
                        (-0.5 * skinSettings.ShadowSharpening + 0.5);
                    double newPosPenumbraSpaceClamped = Math.Min(Math.Max(newPosPenumbraSpace, 0.0), 1.0);
                    double newShadowValue = (3.0 - 2.0 * newPosPenumbraSpaceClamped) * newPosPenumbraSpaceClamped * newPosPenumbraSpaceClamped;

                    rgb[0] += newShadowValue * rgbShadowScattering[0];
                    rgb[1] += newShadowValue * rgbShadowScattering[1];
                    rgb[2] += newShadowValue * rgbShadowScattering[2];
                }

                // Scale sum of samples to get value of integral.  Also hack in a
                // fade to ensure the left edge of the image goes strictly to zero.
                double scale = skinSettings.MaxIntegrationDistanceMM / skinSettings.MonteCarloIterations;
                if (x * 25 < skinSettings.LutSize)
                {
                    scale *= Math.Min(25.0 * x / skinSettings.LutSize, 1.0);
                }
                rgb[0] *= scale;
                rgb[1] *= scale;
                rgb[2] *= scale;


                rgb[0] = Math.Min(Math.Max(rgb[0], 0.0), 1.0);
                rgb[1] = Math.Min(Math.Max(rgb[1], 0.0), 1.0);
                rgb[2] = Math.Min(Math.Max(rgb[2], 0.0), 1.0);

                texture.SetPixel(x, y, new Color((float)rgb[0], (float)rgb[1], (float)rgb[2], 1.0f));
            }
        }
        SaveTexture(texture, path);
    }

    private void BakeCurvatureLUT(SkinSettings skinSettings)
    {
        var path = AssetDatabase.GetAssetPath(skinSettings.CurvatureLUT);
        var texture = new Texture2D(skinSettings.LutSize, skinSettings.LutSize, TextureFormat.RGBAFloat, false, true);

        // The diffusion skinSettings is built assuming a (standard human skin) radiusMM
        // of 2.7 mm, so the curvatures and shadow widths need to be scaled to generate
        // a LUT for the user's desired diffusion radiusMM.
        double diffusionRadiusFactor = skinSettings.DiffusionRadiusMM / HUMAN_SKIN_DEFAULT_DIFFUSION_RADIUS_MM;

        //curvature = 1.0 / radiusMM
        double curvatureMin = diffusionRadiusFactor / skinSettings.MaxCurvatureRadiusMM;
        double curvatureMax = diffusionRadiusFactor / skinSettings.MinCurvatureRadiusMM;

        var curvatureScale = (curvatureMax - curvatureMin) / skinSettings.LutSize;
        var curvatureBias = curvatureMin + 0.5 * curvatureScale;

        var ndlScale = 2.0 / skinSettings.LutSize;
        var ndlBias = -1.0 + 0.5 * ndlScale;

        var res = new double[3];
        var rgbDiffuseScatteringCoeffs = new double[3];

        for (int y = 0; y < skinSettings.LutSize; y++)
        {
            for (int x = 0; x < skinSettings.LutSize; x++)
            {
                double ndl = x * ndlScale + ndlBias;
                double ndlSaturated = Math.Max(0.0, ndl);
                double thetaRadians = Math.Acos(ndl);

                double curvature = y * curvatureScale + curvatureBias;
                double radiusMM = 1.0 / curvature;

                res[0] = 0;
                res[1] = 0;
                res[2] = 0;

                double maxHalfIntegrationLengthMM = skinSettings.MaxIntegrationDistanceMM;
                double lowerIntegrationBoundMM = Math.Max(-Math.PI * radiusMM, -maxHalfIntegrationLengthMM);
                double upperIntegrationBoundMM = Math.Min(Math.PI * radiusMM, maxHalfIntegrationLengthMM);
                double integrationLengthMM = upperIntegrationBoundMM - lowerIntegrationBoundMM;

                double integrationScaleMM = integrationLengthMM / skinSettings.MonteCarloIterations;
                double integrationStepBiasMM = lowerIntegrationBoundMM + 0.5 * integrationScaleMM;

                for (int i = 0; i < skinSettings.MonteCarloIterations; i++)
                {
                    double arcOffsetMM = i * integrationScaleMM + integrationStepBiasMM;
                    SumOfGaussians(arcOffsetMM, rgbDiffuseScatteringCoeffs);

                    double angleOffsetRadians = arcOffsetMM / radiusMM;
                    double ndlDelta = Math.Max(0.0, Math.Cos(thetaRadians - angleOffsetRadians));

                    res[0] += ndlDelta * rgbDiffuseScatteringCoeffs[0] * integrationLengthMM;
                    res[1] += ndlDelta * rgbDiffuseScatteringCoeffs[1] * integrationLengthMM;
                    res[2] += ndlDelta * rgbDiffuseScatteringCoeffs[2] * integrationLengthMM;
                }

                res[0] /= skinSettings.MonteCarloIterations;
                res[1] /= skinSettings.MonteCarloIterations;
                res[2] /= skinSettings.MonteCarloIterations;

                // Calculate offsetMM from standard diffuse lighting (saturate(N.L)) to
                // scattered result, remapped from [-.25, .25] to [0, 1].
                res[0] = (res[0] - ndlSaturated) * 2.0 + 0.5;
                res[1] = (res[1] - ndlSaturated) * 2.0 + 0.5;
                res[2] = (res[2] - ndlSaturated) * 2.0 + 0.5;

                res[0] = Math.Min(Math.Max(res[0], 0.0), 1.0);
                res[1] = Math.Min(Math.Max(res[1], 0.0), 1.0);
                res[2] = Math.Min(Math.Max(res[2], 0.0), 1.0);

                texture.SetPixel(x, y, new Color((float)res[0], (float)res[1], (float)res[2], 1.0f));
            }
        }

        SaveTexture(texture, path);
    }

    private void SumOfGaussians(double r, double[] rgb)
    {
        rgb[0] = 0.0f;
        rgb[1] = 0.0f;
        rgb[2] = 0.0f;

        for (int i = 0; i < _diffusionVariance.Length; ++i)
        {
            double variance = _diffusionVariance[i];
            double gaussian = (
                1.0 / Math.Sqrt(2.0 * Math.PI * variance) *
                Math.Exp(-(r * r) / (2.0 * variance))
            );

            rgb[0] += _diffusionWeightsR[i] * gaussian;
            rgb[1] += _diffusionWeightsG[i] * gaussian;
            rgb[2] += _diffusionWeightsB[i] * gaussian;
        }
    }

    private void SaveTexture(Texture2D texture, string path)
    {
        var binary = texture.EncodeToTGA();
        File.WriteAllBytes(path, binary);
        AssetDatabase.Refresh();
    }
}