using UnityEngine;
using UnityEditor;

public static class ScreenshotCapture
{
    [MenuItem("Tools/Capture Screenshot")]
    public static void Capture()
    {
        var cam = Camera.main;
        if (cam == null) { Debug.LogError("No main camera"); return; }

        var rt = new RenderTexture(1920, 1080, 24, RenderTextureFormat.ARGB32);
        cam.targetTexture = rt;
        cam.Render();
        cam.targetTexture = null;

        var tex = new Texture2D(1920, 1080, TextureFormat.RGB24, false);
        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, 1920, 1080), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        byte[] bytes = tex.EncodeToPNG();
        string path = System.IO.Path.Combine(Application.dataPath, "..", "Temp", "screenshot_debug.png");
        System.IO.File.WriteAllBytes(path, bytes);
        Debug.Log($"Screenshot saved to {path} ({bytes.Length} bytes)");

        Object.DestroyImmediate(tex);
        Object.DestroyImmediate(rt);
    }
}
