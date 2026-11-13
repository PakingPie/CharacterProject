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

public static class CelCharacterStudy
{
 public const string Root="Assets/CelCharacterStudy";
 public const string ScenePath=Root+"/CelComparison.unity";
 public const string Output="D:/School-Life-Game/Saved/Validation/CelCharacterStudy";
 const string TexRoot="Assets/unity-chan!/Unity-chan! Model/Art/UnityChanShader/Texture/";
 [Serializable] public class RootState{public string name;public bool active;}
 [Serializable] public class SourceState{public string path;public bool dirty;public RootState[] roots;}
 [Serializable] public class FaceState{public string name;public float[] weights;}
 [Serializable] public class RigData{public Quaternion headToModel;public Vector3 faceOriginLocal;public FaceState[] faces;}
 static string Safe(string s){return s.Replace(' ','_').Replace('/','_');}
 static void Check(){if(!Application.dataPath.Replace('\\','/').EndsWith("/CharacterProject/Assets"))throw new Exception("Wrong project");if(EditorApplication.isPlaying)throw new Exception("Editor-only study: stop Play mode first");}
 static void F(Material m,string p,float v){if(m.HasProperty(p))m.SetFloat(p,v);}
 static Color SRGB(string hex){Color c;ColorUtility.TryParseHtmlString(hex,out c);return c;}
 static Material Save(Material m,string path){if(AssetDatabase.LoadAssetAtPath<Material>(path)!=null)throw new Exception("Refuse existing "+path);AssetDatabase.CreateAsset(m,path);return m;}
 static GameObject Find(string n){return SceneManager.GetActiveScene().GetRootGameObjects().First(g=>g.name==n);}
 static bool Cloth(Material m){return m.name.Contains("Cloth");}
 static Texture2D FaceMask()
 {
  var t=new Texture2D(256,256,TextureFormat.RFloat,false,true){name="Face_HorizontalSweep",filterMode=FilterMode.Bilinear,wrapMode=TextureWrapMode.Clamp};
  var pixels=new Color[256*256];
  for(int y=0;y<256;y++)for(int x=0;x<256;x++)
  {
   float sx=(x+.5f)/128-1,sy=(y+.5f)/128-1;
   // Explicit contour controls: broad cheek, temple inset, small nose bridge projection.
   float cheek=.06f*Mathf.Exp(-Mathf.Pow((sy+.45f)/.33f,2));
   float temple=-.07f*Mathf.Exp(-Mathf.Pow((sy-.30f)/.25f,2));
   float nose=.10f*Mathf.Exp(-Mathf.Pow(sx/.16f,2)-Mathf.Pow((sy+.13f)/.15f,2));
   float allowed=Mathf.Clamp(.5f+.42f*sx+cheek+temple+nose,.04f,.96f);
   pixels[y*256+x]=new Color(allowed,allowed,allowed,1);
  }
  t.SetPixels(pixels);t.Apply();AssetDatabase.CreateAsset(t,Root+"/Face_HorizontalSweep.asset");
  var preview=new Texture2D(256,256,TextureFormat.RGB24,false,true);preview.SetPixels(pixels);preview.Apply();File.WriteAllBytes(Output+"/face-mask.png",preview.EncodeToPNG());Object.DestroyImmediate(preview);return t;
 }
 static Material Eye(Material source,bool sclera)
 {
  var m=new Material(Shader.Find("SchoolLife/CelStudy/AnimeEye")){name=source.name};
  m.SetTexture("_BaseMap",source.GetTexture("_MainTex"));F(m,"_EyeRegion",sclera?0:1);
  m.SetColor("_ScleraColor",SRGB("#DDDCD0"));m.SetColor("_IrisTop",SRGB("#244E47"));
  m.SetColor("_IrisBottom",SRGB("#A2C77A"));m.SetColor("_PupilColor",SRGB("#142B2B"));
  m.SetColor("_CatchlightColor",SRGB("#F4F8E9"));F(m,"_IrisDetail",.16f);F(m,"_UpperShadow",.28f);F(m,"_CatchlightStrength",.85f);F(m,"_DirectScale",.65f);
  return Save(m,Root+"/Materials/Candidate/"+Safe(source.name)+".mat");
 }
 static Material Candidate(Material source,Texture mask)
 {
  if(source.name.Contains("Left Eye")||source.name=="eyebase")return Eye(source,source.name=="eyebase");
  var m=new Material(source){name=source.name};m.shader=Shader.Find("Unlit/MyToonShader");
  bool face=source.name=="UnityChanHair Face",skin=face||source.name.Contains("Skin"),hair=source.name=="UnityChanHair";
  bool marks=source.name.Contains("Face 1"),cheek=source.name.Contains("Cheek");
  F(m,"_SceneAwareLighting",1);F(m,"_SceneDirectScale",.65f);F(m,"_SceneAmbientScale",1);
  F(m,"_BaseColorStep",.55f);F(m,"_BaseShadeFeather",.0015f);F(m,"_ShadeColorStep",0);F(m,"_FirstAndSecondShadesFeather",.0015f);
  F(m,"_UseBaseTexAsFirstShadowTex",1);F(m,"_UseFirstShadowTexAsSecondShadowTex",1);
  m.SetColor("_BaseColor",Color.white);m.SetColor("_FirstShadowTexColor",(skin?new Color(.66f,.64f,.70f):new Color(.48f,.52f,.66f)).gamma);m.SetColor("_SecondShadowTexColor",m.GetColor("_FirstShadowTexColor"));
  F(m,"_AlbedoFlatten",skin?.90f:hair?.77f:0);F(m,"_AlbedoPreserveDark",skin?.92f:0);
  m.SetColor("_AlbedoFlatColor",SRGB(skin?"#F0D9C3":"#DCAA54"));
  F(m,"_UseAuthoredFaceShadow",face?1:0);m.SetTexture("_FaceShadowTex",mask);F(m,"_FaceShadowFeather",.0025f);
  F(m,"_UseNormalMapOverBase",0);F(m,"_RimLight",0);F(m,"_MatCap",0);F(m,"_AngelRing",0);F(m,"_GIIntensity",0);
  m.SetColor("_HighlightColor",Color.black);m.SetColor("_EmissiveColor",Color.black);
  F(m,"_OutlineThickness",hair?.55f:0);m.SetColor("_OutlineColor",SRGB("#4E392D"));m.SetShaderPassEnabled("Outline",hair);
  if(face)m.SetShaderPassEnabled("ShadowCaster",false);
  m.SetTexture("_BaseMap",source.GetTexture("_MainTex"));F(m,"_Cutoff",.3f);
  if(marks||cheek)
  {
   m.DisableKeyword("_CLIPPING_DISABLE");m.DisableKeyword("_CLIPPING_ENABLE_STDMODE");m.EnableKeyword("_CLIPPING_ENABLE_TRANSMODE");
   F(m,"_CLIPPING",2);F(m,"_UseBaseMapAlphaAsClippingMask",1);F(m,"_ClippingLevel",cheek?.49f:.2f);
   m.SetShaderPassEnabled("ShadowCaster",false);m.SetShaderPassEnabled("Outline",false);
   m.renderQueue=cheek?3000:2450;F(m,"_ZWrite",cheek?0:1);
  }
  return Save(m,Root+"/Materials/Candidate/"+Safe(source.name)+".mat");
 }
 [MenuItem("School Life Cel Study/Build isolated candidate")]
 public static void Build()
 {
  Check();if(File.Exists(ScenePath))throw new Exception("Existing candidate scene; refuse rebuild");
  var original=SceneManager.GetActiveScene();var source=original.GetRootGameObjects().First(g=>g.name=="unitychan");
  Directory.CreateDirectory(Output);Directory.CreateDirectory(Root+"/Materials/Baseline");Directory.CreateDirectory(Root+"/Materials/Candidate");AssetDatabase.Refresh();
  var state=new SourceState{path=original.path,dirty=original.isDirty,roots=original.GetRootGameObjects().Select(g=>new RootState{name=g.name,active=g.activeSelf}).ToArray()};
  File.WriteAllText(Output+"/source-state.json",JsonUtility.ToJson(state,true));
  if(!EditorSceneManager.SaveScene(original,Root+"/SourceScene-Recovery.unity",true))throw new Exception("Recovery save failed");
  var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Additive);SceneManager.SetActiveScene(scene);
  var model=Object.Instantiate(source);model.name="Cel_UnityChan";SceneManager.MoveGameObjectToScene(model,scene);
  foreach(var b in model.GetComponentsInChildren<Behaviour>(true))b.enabled=false;
  model.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);model.transform.localScale=Vector3.one;
  var mats=model.GetComponentsInChildren<Renderer>(true).SelectMany(r=>r.sharedMaterials).Where(m=>m!=null).Distinct().ToArray();
  var fabric=new Material(AssetDatabase.LoadAssetAtPath<Material>("Assets/SchoolLifeNPRStudy/Materials/Shared_Fabric.mat")){name="Shared_Fabric"};Save(fabric,Root+"/Materials/Shared_Fabric.mat");
  var mask=FaceMask();
  foreach(var m in mats.Where(m=>!Cloth(m)))
  {
   var old=new Material(m);if(m.shader.name=="Unlit/MyToonShader")old.shader=Shader.Find("SchoolLife/CelStudy/PreservedToon");
   Save(old,Root+"/Materials/Baseline/"+Safe(m.name)+".mat");Candidate(m,mask);
  }
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))r.sharedMaterials=r.sharedMaterials.Select(m=>Cloth(m)?fabric:AssetDatabase.LoadAssetAtPath<Material>(Root+"/Materials/Candidate/"+Safe(m.name)+".mat")).ToArray();
  model.SetActive(true);Idle().SampleAnimation(model,0);
  var head=model.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Character1_Head");
  var eyes=model.GetComponentsInChildren<Renderer>(true).Where(r=>r.name=="eye_L_old"||r.name=="eye_R_old").ToArray();
  var rig=new RigData{headToModel=Quaternion.Inverse(head.rotation)*model.transform.rotation,faceOriginLocal=head.InverseTransformPoint((eyes[0].bounds.center+eyes[1].bounds.center)*.5f),faces=model.GetComponentsInChildren<SkinnedMeshRenderer>(true).Where(r=>r.sharedMesh.blendShapeCount>0).Select(r=>new FaceState{name=r.name,weights=Enumerable.Range(0,r.sharedMesh.blendShapeCount).Select(r.GetBlendShapeWeight).ToArray()}).ToArray()};
  File.WriteAllText(Root+"/RigCalibration.json",JsonUtility.ToJson(rig,true));
  var basisDriver=model.AddComponent<CelFaceBasis>();basisDriver.head=head;basisDriver.headToModel=rig.headToModel;basisDriver.faceOriginInHead=rig.faceOriginLocal;basisDriver.targets=model.GetComponentsInChildren<Renderer>(true);basisDriver.Apply();
  var floor=GameObject.CreatePrimitive(PrimitiveType.Cube);floor.name="Cel_Floor";floor.transform.position=new Vector3(0,-.06f,0);floor.transform.localScale=new Vector3(8,.1f,8);floor.GetComponent<Renderer>().sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>("Assets/SchoolLifeNPRStudy/Materials/WarmStone.mat");
  var blocker=GameObject.CreatePrimitive(PrimitiveType.Cube);blocker.name="Cel_Blocker";blocker.transform.localScale=new Vector3(3,4,.12f);blocker.GetComponent<Renderer>().shadowCastingMode=ShadowCastingMode.ShadowsOnly;blocker.SetActive(false);
  var key=new GameObject("Cel_Key").AddComponent<Light>();key.type=LightType.Directional;key.shadows=LightShadows.Soft;key.gameObject.AddComponent<UniversalAdditionalLightData>().softShadowQuality=SoftShadowQuality.Low;key.shadowBias=.10f;key.shadowNormalBias=.35f;
  var lamp=new GameObject("Cel_Lamp").AddComponent<Light>();lamp.type=LightType.Point;lamp.range=6;lamp.shadows=LightShadows.Soft;lamp.gameObject.AddComponent<UniversalAdditionalLightData>().softShadowQuality=SoftShadowQuality.Low;lamp.transform.position=new Vector3(-1,2,1);lamp.color=new Color(1,.69f,.38f);lamp.enabled=false;
  var camera=new GameObject("Cel_Camera").AddComponent<Camera>();camera.tag="MainCamera";camera.nearClipPlane=.05f;camera.farClipPlane=6;camera.fieldOfView=32;camera.clearFlags=CameraClearFlags.SolidColor;camera.allowHDR=false;camera.GetUniversalAdditionalCameraData().renderPostProcessing=false;
  RenderSettings.skybox=null;RenderSettings.fog=false;RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.reflectionIntensity=0;
  SessionState.SetBool("CelStudy.SourceSuspended",true);foreach(var g in original.GetRootGameObjects())g.SetActive(false);
  EnsureProxies();SetCase("Candidate","Front",0,0,0,false,0);EditorSceneManager.SaveScene(scene,ScenePath);
 }
 public static void EnsureProxies()
 {
  var model=Find("Cel_UnityChan");if(model.GetComponentsInChildren<Transform>(true).Any(t=>t.name=="Cel_ShadowProxies"))return;
  var rig=JsonUtility.FromJson<RigData>(File.ReadAllText(Root+"/RigCalibration.json"));var head=model.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Character1_Head");
  var holder=new GameObject("Cel_ShadowProxies");holder.transform.SetParent(head,false);holder.transform.localPosition=rig.faceOriginLocal;holder.transform.localRotation=rig.headToModel;var s=head.lossyScale;holder.transform.localScale=new Vector3(1/s.x,1/s.y,1/s.z);
  Proxy(holder.transform,"Head volume",PrimitiveType.Sphere,new Vector3(0,.005f,-.055f),new Vector3(.13f,.17f,.13f));
  Wedge(holder.transform,"Fringe_L",new Vector2(-.075f,.085f),new Vector2(-.026f,.08f),new Vector2(-.032f,.047f));
  Wedge(holder.transform,"Fringe_C",new Vector2(-.012f,.080f),new Vector2(.012f,.080f),new Vector2(.006f,.035f));
  Wedge(holder.transform,"Fringe_R",new Vector2(.028f,.08f),new Vector2(.075f,.085f),new Vector2(.038f,.050f));
 }
 public static void RebuildProxies()
 {
  Check();if(SceneManager.GetActiveScene().path!=ScenePath)throw new Exception("Only rebuild in the candidate scene");
  var model=Find("Cel_UnityChan");var old=model.GetComponentsInChildren<Transform>(true).FirstOrDefault(t=>t.name=="Cel_ShadowProxies");if(old!=null)Object.DestroyImmediate(old.gameObject);EnsureProxies();
 }
 static void Wedge(Transform parent,string name,Vector2 a,Vector2 b,Vector2 c)
 {
  Directory.CreateDirectory(Root+"/ShadowMeshes");AssetDatabase.Refresh();var path=Root+"/ShadowMeshes/"+name+".asset";
  var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
  if(mesh==null)
  {
   Vector3 p0=new Vector3(a.x,a.y,.010f),p1=new Vector3(b.x,b.y,.010f),p2=new Vector3(c.x,c.y,.010f),d=new Vector3(0,0,.006f);
   var v=new List<Vector3>();Action<Vector3,Vector3,Vector3> tri=(x,y,z)=>{v.Add(x);v.Add(y);v.Add(z);};
   tri(p0,p2,p1);tri(p0+d,p1+d,p2+d);tri(p0,p1,p1+d);tri(p0,p1+d,p0+d);tri(p1,p2,p2+d);tri(p1,p2+d,p1+d);tri(p2,p0,p0+d);tri(p2,p0+d,p2+d);
   mesh=new Mesh{name=name};mesh.SetVertices(v);mesh.SetTriangles(Enumerable.Range(0,v.Count).ToArray(),0);mesh.RecalculateNormals();mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,path);
  }
  var g=new GameObject(name);g.transform.SetParent(parent,false);g.AddComponent<MeshFilter>().sharedMesh=mesh;var r=g.AddComponent<MeshRenderer>();r.sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>("Assets/SchoolLifeNPRStudy/Materials/WarmStone.mat");r.shadowCastingMode=ShadowCastingMode.ShadowsOnly;
 }
 static void Proxy(Transform parent,string name,PrimitiveType type,Vector3 position,Vector3 scale)
 {
  var g=GameObject.CreatePrimitive(type);g.name=name;g.transform.SetParent(parent,false);g.transform.localPosition=position;g.transform.localScale=scale;Object.DestroyImmediate(g.GetComponent<Collider>());
  var r=g.GetComponent<Renderer>();r.sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>("Assets/SchoolLifeNPRStudy/Materials/WarmStone.mat");r.shadowCastingMode=ShadowCastingMode.ShadowsOnly;
 }
 static AnimationClip Idle(){return AssetDatabase.LoadAllAssetsAtPath("Assets/unity-chan!/Unity-chan! Model/Art/Animations/unitychan_WAIT00.fbx").OfType<AnimationClip>().First(c=>c.name=="WAIT00");}
 static void Pose(float yaw,float pitch,bool blink,float gaze)
 {
  var model=Find("Cel_UnityChan");var rig=JsonUtility.FromJson<RigData>(File.ReadAllText(Root+"/RigCalibration.json"));
  foreach(var r in model.GetComponentsInChildren<SkinnedMeshRenderer>(true)){r.forceMatrixRecalculationPerRender=true;r.updateWhenOffscreen=true;var f=rig.faces.FirstOrDefault(x=>x.name==r.name);if(f!=null)for(int i=0;i<f.weights.Length;i++)r.SetBlendShapeWeight(i,f.weights[i]);}
  Idle().SampleAnimation(model,0);var head=model.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Character1_Head");head.rotation=Quaternion.Euler(pitch,yaw,0)*head.rotation;
  var basis=head.rotation*rig.headToModel;
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
  {var p=new MaterialPropertyBlock();p.SetVector("_HeadForwardWS",basis*Vector3.forward);p.SetVector("_HeadRightWS",basis*Vector3.right);p.SetVector("_HeadUpWS",basis*Vector3.up);p.SetVector("_FaceOriginWS",head.TransformPoint(rig.faceOriginLocal));p.SetVector("_EyeForwardWS",basis*Vector3.forward);p.SetVector("_GazeOffset",new Vector4(gaze,0,0,0));r.SetPropertyBlock(p);}
  if(blink){var c=AssetDatabase.LoadAssetAtPath<AnimationClip>("Assets/unity-chan!/Unity-chan! Model/Art/Animations/FaceAnimation/eye_close@unitychan.anim");foreach(var b in AnimationUtility.GetCurveBindings(c)){if(b.type!=typeof(SkinnedMeshRenderer)||!b.propertyName.StartsWith("blendShape."))continue;var t=model.transform.Find(b.path);if(t==null)continue;var r=t.GetComponent<SkinnedMeshRenderer>();int index=r.sharedMesh.GetBlendShapeIndex(b.propertyName.Substring(11));if(index>=0)r.SetBlendShapeWeight(index,AnimationUtility.GetEditorCurve(c,b).Evaluate(.25f));}}
 }
 public static void SetCase(string look,string lighting,float viewYaw,float headYaw,float pitch,bool blink,float gaze)
 {
  Check();var model=Find("Cel_UnityChan");
  foreach(var r in model.GetComponentsInChildren<Renderer>(true))
  {
   if(r.shadowCastingMode==ShadowCastingMode.ShadowsOnly)continue;
   r.sharedMaterials=r.sharedMaterials.Select(m=>{var path=AssetDatabase.GetAssetPath(m);return path.EndsWith("Shared_Fabric.mat")?m:AssetDatabase.LoadAssetAtPath<Material>(Root+"/Materials/"+look+"/"+Path.GetFileName(path));}).ToArray();
   if(r.name=="hair_front"||r.name=="hair_frontside")r.shadowCastingMode=look=="Candidate"?ShadowCastingMode.Off:ShadowCastingMode.On;
  }
  Pose(headYaw,pitch,blink,gaze);
  model.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Cel_ShadowProxies").gameObject.SetActive(look=="Candidate");
  var key=Find("Cel_Key").GetComponent<Light>();key.transform.rotation=Quaternion.Euler(35,-145,0);key.intensity=1.2f;key.color=Color.white;
  var ambient=new Color(.38f,.42f,.47f);var bg=new Color(.25f,.32f,.38f);
  var lamp=Find("Cel_Lamp").GetComponent<Light>();lamp.enabled=false;
  if(lighting=="Side")key.transform.rotation=Quaternion.Euler(25,-100,0);
  if(lighting=="Back")key.transform.rotation=Quaternion.Euler(30,35,0);
  if(lighting=="Overhead")key.transform.rotation=Quaternion.Euler(88,-145,0);
  if(lighting=="Night"){key.intensity=.04f;key.color=new Color(.5f,.65f,1);ambient=new Color(.12f,.15f,.22f);bg=new Color(.025f,.04f,.08f);lamp.enabled=true;lamp.intensity=1.3f;}
  if(lighting=="NoKey"||lighting=="Black")key.intensity=0;
  if(lighting=="Black"){ambient=Color.black;bg=Color.black;}
  RenderSettings.ambientLight=ambient;
  var blocker=Find("Cel_Blocker");blocker.SetActive(lighting=="Blocked");blocker.transform.position=new Vector3(0,1.1f,0)-key.transform.forward*1.7f;blocker.transform.rotation=key.transform.rotation;
  var camera=Find("Cel_Camera").GetComponent<Camera>();camera.backgroundColor=bg;
  var focus=new Vector3(-.04f,1.30f,.05f);camera.transform.position=focus+Quaternion.Euler(0,viewYaw,0)*new Vector3(.03f,.13f,1.17f);camera.transform.LookAt(focus);
  EditorApplication.QueuePlayerLoopUpdate();SceneView.RepaintAll();
 }
 public static string Capture(string name)
 {
  var camera=Find("Cel_Camera").GetComponent<Camera>();var rt=new RenderTexture(2400,1800,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);rt.Create();var small=new RenderTexture(1200,900,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);small.Create();var old=RenderTexture.active;
  try{RenderPipeline.SubmitRenderRequest(camera,new UniversalRenderPipeline.SingleCameraRequest{destination=rt});Graphics.Blit(rt,small);RenderTexture.active=small;var t=new Texture2D(1200,900,TextureFormat.RGB24,false,false);t.ReadPixels(new Rect(0,0,1200,900),0,0);t.Apply();var path=Output+"/"+name+".png";File.WriteAllBytes(path,t.EncodeToPNG());Object.DestroyImmediate(t);return path;}finally{RenderTexture.active=old;rt.Release();small.Release();Object.DestroyImmediate(rt);Object.DestroyImmediate(small);}
 }
 [MenuItem("School Life Cel Study/Candidate front")]
 public static void CandidateFront(){SetCase("Candidate","Front",0,0,0,false,0);}
 [MenuItem("School Life Cel Study/Preserved baseline front")]
 public static void BaselineFront(){SetCase("Baseline","Front",0,0,0,false,0);}
 [MenuItem("School Life Cel Study/Restore source scene")]
 public static void Restore()
 {
  Check();if(!SessionState.GetBool("CelStudy.SourceSuspended",false))throw new Exception("No source suspended in this session");var state=JsonUtility.FromJson<SourceState>(File.ReadAllText(Output+"/source-state.json"));var source=SceneManager.GetSceneByPath(state.path);if(!source.IsValid()||!source.isLoaded)throw new Exception("Live source missing; use recovery copy deliberately");var study=SceneManager.GetSceneByPath(ScenePath);foreach(var g in source.GetRootGameObjects()){var r=state.roots.FirstOrDefault(x=>x.name==g.name);if(r!=null)g.SetActive(r.active);}SceneManager.SetActiveScene(source);if(study.IsValid()&&study.isLoaded)EditorSceneManager.CloseScene(study,true);if(state.dirty)EditorSceneManager.MarkSceneDirty(source);SessionState.SetBool("CelStudy.SourceSuspended",false);
 }
}
#endif
