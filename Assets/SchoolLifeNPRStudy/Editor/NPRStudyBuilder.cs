#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEditor.SceneManagement;
using Object=UnityEngine.Object;

public static class SchoolLifeNprStudy
{
 public const string Root="Assets/SchoolLifeNPRStudy";
 public const string ScenePath=Root+"/NPRComparison.unity";
 public const string Output="D:/School-Life-Game/Saved/Validation/NPRStyleStudy";
 static readonly string TexRoot="Assets/unity-chan!/Unity-chan! Model/Art/UnityChanShader/Texture/";
 [Serializable] public class RootState {public string name;public bool active;}
 [Serializable] public class SourceState {public string path;public bool dirty;public RootState[] roots;}
 [Serializable] public class FaceState {public string name;public float[] weights;}
 [Serializable] public class FaceStates {public FaceState[] renderers;}
 static string Safe(string s) {return s.Replace(' ','_').Replace('/','_');}
 static void CheckProject()
 {
  if(!Application.dataPath.Replace('\\','/').EndsWith("/CharacterProject/Assets"))throw new Exception("Wrong project");
  if(EditorApplication.isPlaying)throw new Exception("Stop Play mode before study operations");
 }
 static void Set(Material m,string p,float v){if(m.HasProperty(p))m.SetFloat(p,v);}
 static Material SaveMat(Material m,string path)
 {
  if(AssetDatabase.LoadAssetAtPath<Material>(path)!=null)throw new Exception("Refuse to overwrite "+path);
  AssetDatabase.CreateAsset(m,path); return m;
 }
 static Material Fabric(Material original)
 {
  var m=new Material(Shader.Find("Custom/FabricPBR_TextureBased")){name="Shared_Fabric"};
  m.SetTexture("_MainTex",original.GetTexture("_MainTex")); m.SetColor("_BaseColor",Color.white);
  var normalPath=Root+"/BodyNormal.tga";
  if(!File.Exists(normalPath))AssetDatabase.CopyAsset(TexRoot+"body_01_NRM.tga",normalPath);
  var normalImporter=(TextureImporter)AssetImporter.GetAtPath(normalPath);
  normalImporter.textureType=TextureImporterType.NormalMap;normalImporter.sRGBTexture=false;normalImporter.SaveAndReimport();
  m.SetTexture("_NormalMap",AssetDatabase.LoadAssetAtPath<Texture>(normalPath));
  Set(m,"_UseNormalMap",1);Set(m,"_NormalStrength",.2f);Set(m,"_Roughness",.78f);
  Set(m,"_Anisotropy",.12f);Set(m,"_FabricSpecAttenuation",.55f);Set(m,"_Sheen",.08f);
  Set(m,"_FuzzIntensity",0);Set(m,"_Subsurface",0);Set(m,"_StripSpecIntensity",0);
  Set(m,"_TwoLayerDarkening",0);Set(m,"_ForwardZWrite",1);Set(m,"_Opacity",1);
  Set(m,"_UseOpacityMap",0);Set(m,"_UseAOMap",0);Set(m,"_UseRoughnessMap",0);
  // In this source shader the toggle enables diffuse probe lighting as well as specular IBL.
  Set(m,"_UseReflectiveProbe",1);Set(m,"_DiffuseWrap",0);Set(m,"_EnableEmission",0);
  m.renderQueue=2000;
  return SaveMat(m,Root+"/Materials/Shared_Fabric.mat");
 }
 static bool IsCloth(Material m){return m.name.Contains("Cloth");}
 static Material NPR(Material source,string look)
 {
  bool hair=source.name=="UnityChanHair";
  bool skin=source.name.Contains("Skin")||source.name=="UnityChanHair Face";
  bool alpha=source.name.Contains("Face 1")||source.name.Contains("Cheek")||source.name.Contains("Eye")||source.name=="eyebase";
  var m=new Material(Shader.Find("SchoolLife/Study/SceneLitNPR")){name=look+"_"+source.name};
  m.SetTexture("_BaseMap",source.HasProperty("_MainTex")?source.GetTexture("_MainTex"):source.mainTexture);
  m.SetColor("_BaseColor",Color.white);
  m.SetColor("_ShadowTint",skin?new Color(1f,.86f,.84f):new Color(.87f,.9f,1f));
  Set(m,"_Threshold",hair?.12f:.08f); Set(m,"_Feather",look=="Quiet"?.16f:.018f);
  Set(m,"_ShadowValue",look=="Quiet"?.62f:.36f);
  Set(m,"_Flatten",source.name=="UnityChanHair Face"?.35f:0);
  Set(m,"_Cull",2); Set(m,"_Cutoff",alpha?.3f:0);
  if(alpha){m.EnableKeyword("_ALPHATEST_ON");m.renderQueue=2450;}
  if(source.name.Contains("Cheek"))
  {
   Set(m,"_Cutoff",.001f);Set(m,"_SrcBlend",(float)BlendMode.SrcAlpha);Set(m,"_DstBlend",(float)BlendMode.OneMinusSrcAlpha);Set(m,"_ZWrite",0);m.renderQueue=3000;
   m.SetShaderPassEnabled("ShadowCaster",false);m.SetShaderPassEnabled("DepthOnly",false);
  }
  return SaveMat(m,Root+"/Materials/"+look+"/"+Safe(source.name)+".mat");
 }
 [MenuItem("School Life NPR Study/Build isolated comparison")]
 public static void Build()
 {
  CheckProject();
  if(File.Exists(ScenePath))throw new Exception("Study scene already exists; use its review controls");
  var original=SceneManager.GetActiveScene();
  var source=original.GetRootGameObjects().FirstOrDefault(g=>g.name=="unitychan");
  if(source==null)throw new Exception("Open the existing SampleScene containing the configured Unity-Chan");
  Directory.CreateDirectory(Output);
  var state=new SourceState{path=original.path,dirty=original.isDirty,roots=original.GetRootGameObjects().Select(g=>new RootState{name=g.name,active=g.activeSelf}).ToArray()};
  File.WriteAllText(Output+"/source-state.json",JsonUtility.ToJson(state,true));
  // Save a recovery COPY, retaining the same unsaved source scene live in memory.
  if(!EditorSceneManager.SaveScene(original,Root+"/SourceScene-Recovery.unity",true))throw new Exception("Recovery copy failed");
  Directory.CreateDirectory(Root+"/Materials/Quiet");Directory.CreateDirectory(Root+"/Materials/Graphic");Directory.CreateDirectory(Root+"/Materials/Legacy");
  AssetDatabase.Refresh();
  var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Additive);
  SceneManager.SetActiveScene(scene);
  var model=Object.Instantiate(source);model.name="Study_UnityChan";
  SceneManager.MoveGameObjectToScene(model,scene);
  foreach(var b in model.GetComponentsInChildren<Behaviour>(true))b.enabled=false;
  model.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);model.transform.localScale=Vector3.one;
  var originalMats=model.GetComponentsInChildren<Renderer>(true).SelectMany(r=>r.sharedMaterials).Where(m=>m!=null).Distinct().ToArray();
  var fabric=Fabric(originalMats.First(IsCloth));
  foreach(var m in originalMats.Where(m=>!IsCloth(m)))
  {
   SaveMat(new Material(m){name="Legacy_"+m.name},Root+"/Materials/Legacy/"+Safe(m.name)+".mat");
   NPR(m,"Quiet");NPR(m,"Graphic");
  }
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
  {
   r.sharedMaterials=r.sharedMaterials.Select(m=>IsCloth(m)?fabric:AssetDatabase.LoadAssetAtPath<Material>(Root+"/Materials/Quiet/"+Safe(m.name)+".mat")).ToArray();
   var s=r as SkinnedMeshRenderer;if(s!=null)s.updateWhenOffscreen=true;
  }
  model.SetActive(true);
  // Preserve source child activation and renderer visibility; only the root becomes visible.
  var idle=AssetDatabase.LoadAllAssetsAtPath("Assets/unity-chan!/Unity-chan! Model/Art/Animations/unitychan_WAIT00.fbx").OfType<AnimationClip>().First(c=>c.name=="WAIT00");
  idle.SampleAnimation(model,0);
  var faces=new FaceStates{renderers=model.GetComponentsInChildren<SkinnedMeshRenderer>(true).Where(r=>r.sharedMesh.blendShapeCount>0).Select(r=>new FaceState{name=r.name,weights=Enumerable.Range(0,r.sharedMesh.blendShapeCount).Select(r.GetBlendShapeWeight).ToArray()}).ToArray()};
  File.WriteAllText(Output+"/neutral-faces.json",JsonUtility.ToJson(faces,true));
  File.WriteAllText(Root+"/NeutralFaceWeights.json",JsonUtility.ToJson(faces,true));
  var floor=GameObject.CreatePrimitive(PrimitiveType.Cube);floor.name="Study_Floor";floor.transform.position=new Vector3(0,-.06f,0);floor.transform.localScale=new Vector3(8,.1f,8);
  var fm=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Study_WarmStone"};fm.SetColor("_BaseColor",new Color(.46f,.43f,.37f));fm.SetFloat("_Smoothness",.12f);
  floor.GetComponent<Renderer>().sharedMaterial=SaveMat(fm,Root+"/Materials/WarmStone.mat");
  var blocker=GameObject.CreatePrimitive(PrimitiveType.Cube);blocker.name="Study_Blocker";blocker.transform.localScale=new Vector3(3,4,.12f);blocker.GetComponent<Renderer>().sharedMaterial=fm;blocker.GetComponent<Renderer>().shadowCastingMode=ShadowCastingMode.ShadowsOnly;blocker.SetActive(false);
  var sun=new GameObject("Study_Key").AddComponent<Light>();sun.type=LightType.Directional;sun.shadows=LightShadows.Soft;sun.shadowBias=.12f;sun.shadowNormalBias=.5f;
  var lamp=new GameObject("Study_Practical").AddComponent<Light>();lamp.type=LightType.Point;lamp.range=6;lamp.shadows=LightShadows.Soft;lamp.transform.position=new Vector3(-1,2,1);lamp.color=new Color(1,.69f,.38f);lamp.enabled=false;
  var camera=new GameObject("Study_Camera").AddComponent<Camera>();camera.tag="MainCamera";camera.nearClipPlane=.05f;camera.farClipPlane=40;camera.fieldOfView=32;camera.clearFlags=CameraClearFlags.SolidColor;camera.allowHDR=false;
  var cd=camera.GetUniversalAdditionalCameraData();cd.renderPostProcessing=false;cd.antialiasing=AntialiasingMode.None;
  RenderSettings.skybox=null;RenderSettings.fog=false;RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.reflectionIntensity=0;
  SessionState.SetBool("SchoolLifeStudy.SourceSuspended",true);
  foreach(var g in original.GetRootGameObjects())g.SetActive(false);
  SetCase("Quiet","Day","Portrait",0,false);
  EditorSceneManager.SaveScene(scene,ScenePath);
  Directory.CreateDirectory(Output);
  File.WriteAllText(Output+"/build.txt","Source: Assets/Scenes/SampleScene.unity; configured unitychan copied. New materials only. Original remains loaded with recovery copy and temporary root deactivation; RestoreSource restores recorded flags. Shared fabric references identical in all variants. New NPR shader has no outline; source texture linework remains. Blocker is an invisible shadow-only diagnostic.\n"+DateTime.UtcNow.ToString("o"));
 }
 static GameObject Find(string name){return SceneManager.GetActiveScene().GetRootGameObjects().First(g=>g.name==name);}
 static void Pose(float yaw,bool blink)
 {
  var model=Find("Study_UnityChan");
  var faces=JsonUtility.FromJson<FaceStates>(File.ReadAllText(Root+"/NeutralFaceWeights.json"));
  foreach(var r in model.GetComponentsInChildren<SkinnedMeshRenderer>(true))
  {r.forceMatrixRecalculationPerRender=true;var f=faces.renderers.FirstOrDefault(x=>x.name==r.name);if(f!=null)for(int i=0;i<f.weights.Length;i++)r.SetBlendShapeWeight(i,f.weights[i]);}
  var clip=AssetDatabase.LoadAllAssetsAtPath("Assets/unity-chan!/Unity-chan! Model/Art/Animations/unitychan_WAIT00.fbx").OfType<AnimationClip>().First(c=>c.name=="WAIT00");
  clip.SampleAnimation(model,0);
  var head=model.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Character1_Head");
  head.rotation=Quaternion.AngleAxis(yaw,Vector3.up)*head.rotation;
  // Imported head axes are not assumed: the neutral forward is model +Z,
  // transformed by the explicit world-yaw delta used by this sampled study.
  Vector3 forward=Quaternion.AngleAxis(yaw,Vector3.up)*model.transform.forward;
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
  {
   var b=new MaterialPropertyBlock();r.GetPropertyBlock(b);b.SetVector("_HeadForward",forward);r.SetPropertyBlock(b);
  }
  if(blink)
  {
   var c=AssetDatabase.LoadAssetAtPath<AnimationClip>("Assets/unity-chan!/Unity-chan! Model/Art/Animations/FaceAnimation/eye_close@unitychan.anim");
   // Sampling a humanoid face clip resets the body pose. Apply only its authored
   // blendshape curves, preserving the already evaluated idle/head transforms.
   foreach(var binding in AnimationUtility.GetCurveBindings(c))
   {
    if(binding.type!=typeof(SkinnedMeshRenderer)||!binding.propertyName.StartsWith("blendShape."))continue;
    var t=model.transform.Find(binding.path);if(t==null)continue;
    var r=t.GetComponent<SkinnedMeshRenderer>();if(r==null)continue;
    int index=r.sharedMesh.GetBlendShapeIndex(binding.propertyName.Substring("blendShape.".Length));
    if(index>=0)r.SetBlendShapeWeight(index,AnimationUtility.GetEditorCurve(c,binding).Evaluate(Mathf.Min(.25f,c.length)));
   }
  }
 }
 public static void SetCase(string look,string lighting,string framing,float yaw,bool blink)
 {
  CheckProject();
  var model=Find("Study_UnityChan");
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
  {
   r.sharedMaterials=r.sharedMaterials.Select(m=>
   {
    var path=AssetDatabase.GetAssetPath(m);if(path.EndsWith("Shared_Fabric.mat"))return m;
    return AssetDatabase.LoadAssetAtPath<Material>(Root+"/Materials/"+look+"/"+Path.GetFileName(path));
   }).ToArray();
  }
  Pose(yaw,blink);
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
   if(r.sharedMaterials.Any(m=>AssetDatabase.GetAssetPath(m).EndsWith("/UnityChanHair.mat")))
    r.shadowCastingMode=lighting=="SideForm"?ShadowCastingMode.Off:ShadowCastingMode.On;
  var sun=Find("Study_Key").GetComponent<Light>();sun.transform.rotation=Quaternion.Euler(40,-145,0);sun.intensity=Mathf.PI;sun.color=Color.white;sun.enabled=true;
  var ambient=new Color(.38f,.42f,.47f);var bg=new Color(.25f,.32f,.38f);
  var lamp=Find("Study_Practical").GetComponent<Light>();lamp.enabled=false;
  if(lighting=="Night") {sun.intensity=.04f;sun.color=new Color(.5f,.65f,1);ambient=new Color(.12f,.15f,.22f);bg=new Color(.025f,.04f,.08f);lamp.enabled=true;lamp.intensity=2.2f;}
  if(lighting=="Side"||lighting=="SideForm")sun.transform.rotation=Quaternion.Euler(20,-90,0);
  if(lighting=="NoKey")sun.intensity=0;
  if(lighting=="Black") {sun.intensity=0;ambient=Color.black;bg=Color.black;}
  RenderSettings.ambientLight=ambient;
  // Flat ambient updates the shared scene SH. Capture after an editor update;
  // do not mix explicit SH coefficients with Unity's gamma-color ambient control.
  var blocker=Find("Study_Blocker");blocker.SetActive(lighting=="Blocked");
  blocker.transform.position=new Vector3(0,1.1f,0)-sun.transform.forward*1.7f;blocker.transform.rotation=sun.transform.rotation;
  var camera=Find("Study_Camera").GetComponent<Camera>();camera.backgroundColor=bg;
  if(framing=="Full") {camera.transform.position=new Vector3(.1f,1.15f,3.9f);camera.transform.LookAt(new Vector3(0,.85f,0));}
  else if(framing=="Rear") {camera.transform.position=new Vector3(-.4f,1.45f,-2.9f);camera.transform.LookAt(new Vector3(0,1.1f,0));}
  else {camera.transform.position=new Vector3(-.01f,1.43f,1.22f);camera.transform.LookAt(new Vector3(-.04f,1.30f,.05f));}
  EditorApplication.QueuePlayerLoopUpdate();SceneView.RepaintAll();
 }
 public static string Capture(string name)
 {
  CheckProject();var camera=Find("Study_Camera").GetComponent<Camera>();
  // 2x supersampling for review stills only, not a runtime quality/performance claim.
  var rt=new RenderTexture(2400,1800,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);rt.Create();
  var resolved=new RenderTexture(1200,900,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);resolved.Create();
  var old=RenderTexture.active;
  try
  {
   var request=new UniversalRenderPipeline.SingleCameraRequest{destination=rt};
   RenderPipeline.SubmitRenderRequest(camera,request);
   Graphics.Blit(rt,resolved);
   RenderTexture.active=resolved;var image=new Texture2D(1200,900,TextureFormat.RGB24,false,false);
   image.ReadPixels(new Rect(0,0,1200,900),0,0);image.Apply();
   var path=Output+"/"+name+".png";File.WriteAllBytes(path,image.EncodeToPNG());Object.DestroyImmediate(image);return path;
  }
  finally{RenderTexture.active=old;rt.Release();resolved.Release();Object.DestroyImmediate(rt);Object.DestroyImmediate(resolved);}
 }
 [MenuItem("School Life NPR Study/Quiet daylight")]
 public static void Quiet(){SetCase("Quiet","Day","Portrait",0,false);}
 [MenuItem("School Life NPR Study/Graphic daylight")]
 public static void Graphic(){SetCase("Graphic","Day","Portrait",0,false);}
 [MenuItem("School Life NPR Study/Quiet building shade")]
 public static void Shade(){SetCase("Quiet","Blocked","Portrait",0,false);}
 [MenuItem("School Life NPR Study/Quiet evening practical")]
 public static void Night(){SetCase("Quiet","Night","Portrait",0,false);}
 [MenuItem("School Life NPR Study/Restore original scene state")]
 public static void RestoreSource()
 {
  CheckProject();
  if(!SessionState.GetBool("SchoolLifeStudy.SourceSuspended",false))throw new Exception("No source scene suspended by this editor session; refusing stale restoration");
  var state=JsonUtility.FromJson<SourceState>(File.ReadAllText(Output+"/source-state.json"));
  var source=SceneManager.GetSceneByPath(state.path);
  if(!source.IsValid()||!source.isLoaded)throw new Exception("Original live scene is no longer loaded; inspect recovery copy instead of discarding work");
  var study=SceneManager.GetSceneByPath(ScenePath);
  foreach(var root in source.GetRootGameObjects()) {var r=state.roots.FirstOrDefault(x=>x.name==root.name);if(r!=null)root.SetActive(r.active);}
  SceneManager.SetActiveScene(source);
  if(study.IsValid()&&study.isLoaded)EditorSceneManager.CloseScene(study,true);
  if(state.dirty)EditorSceneManager.MarkSceneDirty(source);
  SessionState.SetBool("SchoolLifeStudy.SourceSuspended",false);
 }
}
#endif
