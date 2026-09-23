import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try { cameras = await availableCameras(); } catch (_) {}
  runApp(App(cameras));
}

const typeOptions = [
  'เหรียญ','เหรียญหล่อ','พระสมเด็จ','รูปหล่อ','พระกริ่ง',
  'พระปิดตาเนื้อผง/หว้าน','พระปิดตาเนื้อโลหะ','พระเนื้อผง',
  'พระเนื้อดิน','พระนางพญา','ผงสุพรรณ','พระรอด','พระซุ้มกอ',
  'พระขุนแผน','หลวงปู่ทวดเนื้อหว้าน','หลวงปู่ทวดหลังเตารีด',
  'เขี้ยวแกะ','งาแกะ','ตะกรุด','อื่น ๆ',
];
const allAreas = ['ด้านหน้า','ด้านหลัง','ด้านข้าง','ก้นพระ'];

List<String> scanAreasForType(String type) =>
    ['เหรียญ','เหรียญหล่อ','พระขุนแผน'].contains(type)
        ? ['ด้านหน้า','ด้านหลัง','ด้านข้าง'] : allAreas;

const aiHeads = [
  'พิมพ์ทรง','องค์ประกอบ','ลวดลาย','ตำหนิที่มองเห็น','ผิว',
  'ลักษณะเนื้อที่มองเห็น','ขอบ/ด้านข้าง','จุดสังเกต',
  'รายละเอียดอื่น','สิ่งที่อ่านไม่ได้',
];

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String now() => DateTime.now().toIso8601String();

List<T> mapList<T>(dynamic v,T Function(Map<String,dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e)=>f(Map<String,dynamic>.from(e))).toList() : [];

T? firstWhereOrNull<T>(Iterable<T> list,bool Function(T) test) {
  for (final e in list) { if (test(e)) return e; }
  return null;
}

Future<String?> textDialog(BuildContext context,String title,String value,Future<void> Function(String) save) async {
  final c=TextEditingController(text:value);
  final ok=await showDialog<bool>(
    context:context,
    builder:(_)=>AlertDialog(
      title:Text(title),
      content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(border:OutlineInputBorder())),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('ยกเลิก')),
        ElevatedButton(onPressed:() async {
          final v=c.text.trim(); if(v.isEmpty)return;
          await save(v); if(context.mounted)Navigator.pop(context,true);
        },child:const Text('บันทึก')),
      ],
    ),
  );
  final r=ok==true?c.text.trim():null;c.dispose();return r;
}

Future<bool> confirmDelete(BuildContext context,String name) async =>
    await showDialog<bool>(
      context:context,
      builder:(_)=>AlertDialog(
        title:const Text('ยืนยันการลบ'),
        content:Text('ต้องการลบ "$name" หรือไม่?\nข้อมูล AI ที่เกี่ยวข้องจะถูกลบด้วย'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('ยกเลิก')),
          ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ลบ')),
        ],
      ),
    )??false;

class ScanResult {
  String area,details;
  ScanResult({required this.area,required this.details});
  Map<String,dynamic> toMap()=>{'area':area,'details':details};
  factory ScanResult.fromMap(Map<String,dynamic> m)=>ScanResult(area:m['area']??'',details:m['details']??'');
}

class ReferenceData {
  String id,createdAt,updatedAt;
  int referenceNumber;
  List<ScanResult> scans;
  ReferenceData({required this.id,required this.referenceNumber,required this.createdAt,required this.updatedAt,List<ScanResult>? scans}):scans=scans??[];
  Map<String,dynamic> toMap()=>{'id':id,'referenceNumber':referenceNumber,'createdAt':createdAt,'updatedAt':updatedAt,'scans':scans.map((e)=>e.toMap()).toList()};
  factory ReferenceData.fromMap(Map<String,dynamic> m)=>ReferenceData(
    id:m['id']??newId(),referenceNumber:m['referenceNumber']??1,
    createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now(),
    scans:mapList(m['scans'],ScanResult.fromMap));
}

class PrintData {
  String id,name,createdAt,updatedAt;
  List<ReferenceData> references;
  PrintData({required this.id,required this.name,required this.createdAt,required this.updatedAt,List<ReferenceData>? references}):references=references??[];
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'createdAt':createdAt,'updatedAt':updatedAt,'references':references.map((e)=>e.toMap()).toList()};
  factory PrintData.fromMap(Map<String,dynamic> m)=>PrintData(
    id:m['id']??newId(),name:m['name']??'',createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now(),
    references:mapList(m['references'],ReferenceData.fromMap));
}

class TypeData {
  String id,name,createdAt,updatedAt;
  List<PrintData> prints;
  TypeData({required this.id,required this.name,required this.createdAt,required this.updatedAt,List<PrintData>? prints}):prints=prints??[];
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'createdAt':createdAt,'updatedAt':updatedAt,'prints':prints.map((e)=>e.toMap()).toList()};
  factory TypeData.fromMap(Map<String,dynamic> m)=>TypeData(
    id:m['id']??newId(),name:m['name']??'',createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now(),
    prints:mapList(m['prints'],PrintData.fromMap));
}

class ModelData {
  String id,name,createdAt,updatedAt;
  List<TypeData> types;
  ModelData({required this.id,required this.name,required this.createdAt,required this.updatedAt,List<TypeData>? types}):types=types??[];
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'createdAt':createdAt,'updatedAt':updatedAt,'types':types.map((e)=>e.toMap()).toList()};
  factory ModelData.fromMap(Map<String,dynamic> m)=>ModelData(
    id:m['id']??newId(),name:m['name']??'',createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now(),
    types:mapList(m['types'],TypeData.fromMap));
}

class GroupData {
  String id,name,temple,createdAt,updatedAt;
  List<ModelData> models;
  GroupData({required this.id,required this.name,required this.temple,required this.createdAt,required this.updatedAt,List<ModelData>? models}):models=models??[];
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'temple':temple,'createdAt':createdAt,'updatedAt':updatedAt,'models':models.map((e)=>e.toMap()).toList()};
  factory GroupData.fromMap(Map<String,dynamic> m)=>GroupData(
    id:m['id']??newId(),name:m['name']??'',temple:m['temple']??'',createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now(),
    models:mapList(m['models'],ModelData.fromMap));
}

class AiKnowledge {
  String id,groupId,modelId,typeId,printId,referenceId,area,content,createdAt,updatedAt;
  AiKnowledge({required this.id,required this.groupId,required this.modelId,required this.typeId,required this.printId,required this.referenceId,required this.area,required this.content,required this.createdAt,required this.updatedAt});
  Map<String,dynamic> toMap()=>{'id':id,'groupId':groupId,'modelId':modelId,'typeId':typeId,'printId':printId,'referenceId':referenceId,'area':area,'content':content,'createdAt':createdAt,'updatedAt':updatedAt};
  factory AiKnowledge.fromMap(Map<String,dynamic> m)=>AiKnowledge(
    id:m['id']??newId(),groupId:m['groupId']??'',modelId:m['modelId']??'',typeId:m['typeId']??'',printId:m['printId']??'',referenceId:m['referenceId']??'',area:m['area']??'',content:m['content']??'',createdAt:m['createdAt']??now(),updatedAt:m['updatedAt']??now());
}

class AiLearningHistory {
  String id,groupId,modelId,typeId,printId,referenceId,area,content,learnedAt;
  AiLearningHistory({required this.id,required this.groupId,required this.modelId,required this.typeId,required this.printId,required this.referenceId,required this.area,required this.content,required this.learnedAt});
  Map<String,dynamic> toMap()=>{'id':id,'groupId':groupId,'modelId':modelId,'typeId':typeId,'printId':printId,'referenceId':referenceId,'area':area,'content':content,'learnedAt':learnedAt};
  factory AiLearningHistory.fromMap(Map<String,dynamic> m)=>AiLearningHistory(
    id:m['id']??newId(),groupId:m['groupId']??'',modelId:m['modelId']??'',typeId:m['typeId']??'',printId:m['printId']??'',referenceId:m['referenceId']??'',area:m['area']??'',content:m['content']??'',learnedAt:m['learnedAt']??now());
}

class AiMemoryTest {
  String id,knowledgeId,referenceId,area,question,answer,testedAt;
  AiMemoryTest({required this.id,required this.knowledgeId,required this.referenceId,required this.area,required this.question,required this.answer,required this.testedAt});
  Map<String,dynamic> toMap()=>{'id':id,'knowledgeId':knowledgeId,'referenceId':referenceId,'area':area,'question':question,'answer':answer,'testedAt':testedAt};
  factory AiMemoryTest.fromMap(Map<String,dynamic> m)=>AiMemoryTest(
    id:m['id']??newId(),knowledgeId:m['knowledgeId']??'',referenceId:m['referenceId']??'',area:m['area']??'',question:m['question']??'',answer:m['answer']??'',testedAt:m['testedAt']??now());
}

class AiTestResult {
  String id,testId,knowledgeId,referenceId,area,mode,result,answer,referenceAnswer,reason,checkedAt;
  AiTestResult({required this.id,required this.testId,required this.knowledgeId,required this.referenceId,required this.area,required this.mode,required this.result,required this.answer,required this.referenceAnswer,required this.reason,required this.checkedAt});
  Map<String,dynamic> toMap()=>{'id':id,'testId':testId,'knowledgeId':knowledgeId,'referenceId':referenceId,'area':area,'mode':mode,'result':result,'answer':answer,'referenceAnswer':referenceAnswer,'reason':reason,'checkedAt':checkedAt};
  factory AiTestResult.fromMap(Map<String,dynamic> m)=>AiTestResult(
    id:m['id']??newId(),testId:m['testId']??'',knowledgeId:m['knowledgeId']??'',referenceId:m['referenceId']??'',area:m['area']??'',mode:m['mode']??'',result:m['result']??'',answer:m['answer']??'',referenceAnswer:m['referenceAnswer']??'',reason:m['reason']??'',checkedAt:m['checkedAt']??now());
}

class _RefLink {
  final GroupData group;final ModelData model;final TypeData type;final PrintData print;final ReferenceData reference;
  _RefLink(this.group,this.model,this.type,this.print,this.reference);
}

class Storage {
  static const groupsKey='reference_groups',knowledgeKey='ai_knowledge',historyKey='ai_learning_history',testsKey='ai_memory_tests',resultsKey='ai_test_results';

  static Future<List<T>> _get<T>(String key,T Function(Map<String,dynamic>) f) async {
    final p=await SharedPreferences.getInstance(),s=p.getString(key);
    if(s==null||s.isEmpty)return [];
    try{return mapList(jsonDecode(s),f);}catch(_){return [];}
  }
  static Future<void> _save<T>(String key,List<T> list,Map<String,dynamic> Function(T) f) async {
    final p=await SharedPreferences.getInstance();
    await p.setString(key,jsonEncode(list.map(f).toList()));
  }
  static Future<List<GroupData>> groups()=>_get(groupsKey,GroupData.fromMap);
  static Future<void> saveGroups(List<GroupData> v)=>_save(groupsKey,v,(e)=>e.toMap());
  static Future<void> saveGroup(GroupData g) async {
    final a=await groups();final i=a.indexWhere((e)=>e.id==g.id);
    if(i<0)a.add(g);else a[i]=g;await saveGroups(a);
  }
  static Future<List<AiKnowledge>> knowledge()=>_get(knowledgeKey,AiKnowledge.fromMap);
  static Future<void> saveKnowledge(List<AiKnowledge> v)=>_save(knowledgeKey,v,(e)=>e.toMap());
  static Future<List<AiLearningHistory>> history()=>_get(historyKey,AiLearningHistory.fromMap);
  static Future<void> saveHistory(List<AiLearningHistory> v)=>_save(historyKey,v,(e)=>e.toMap());
  static Future<List<AiMemoryTest>> tests()=>_get(testsKey,AiMemoryTest.fromMap);
  static Future<void> saveTests(List<AiMemoryTest> v)=>_save(testsKey,v,(e)=>e.toMap());
  static Future<List<AiTestResult>> results()=>_get(resultsKey,AiTestResult.fromMap);
  static Future<void> saveResults(List<AiTestResult> v)=>_save(resultsKey,v,(e)=>e.toMap());

  static Iterable<_RefLink> links(GroupData g) sync* {
    for(final m in g.models)for(final t in m.types)for(final p in t.prints)for(final r in p.references)yield _RefLink(g,m,t,p,r);
  }
  static Set<String> refIds(Iterable<_RefLink> v)=>v.map((e)=>e.reference.id).toSet();

  static Future<void> clearAiByScope({String? groupId,String? modelId,String? typeId,String? printId,Set<String>? referenceIds}) async {
    final refs=referenceIds??{},k=await knowledge(),h=await history(),tests=await Storage.tests(),results=await Storage.results();
    bool matchK(AiKnowledge e)=>refs.contains(e.referenceId)||(groupId!=null&&e.groupId==groupId)||(modelId!=null&&e.modelId==modelId)||(typeId!=null&&e.typeId==typeId)||(printId!=null&&e.printId==printId);
    bool matchH(AiLearningHistory e)=>refs.contains(e.referenceId)||(groupId!=null&&e.groupId==groupId)||(modelId!=null&&e.modelId==modelId)||(typeId!=null&&e.typeId==typeId)||(printId!=null&&e.printId==printId);
    final matchedK=k.where(matchK).toList(),kid=matchedK.map((e)=>e.id).toSet();
    final ref={...refs,...matchedK.map((e)=>e.referenceId)};
    final matchedT=tests.where((e)=>ref.contains(e.referenceId)||kid.contains(e.knowledgeId)).toList(),tid=matchedT.map((e)=>e.id).toSet();
    k.removeWhere(matchK);h.removeWhere(matchH);
    tests.removeWhere((e)=>ref.contains(e.referenceId)||kid.contains(e.knowledgeId));
    results.removeWhere((e)=>ref.contains(e.referenceId)||kid.contains(e.knowledgeId)||tid.contains(e.testId));
    await Future.wait([saveKnowledge(k),saveHistory(h),saveTests(tests),saveResults(results)]);
  }

  static Future<void> clearAiByArea(String referenceId,String area) async {
    final k=await knowledge(),h=await history(),tests=await Storage.tests(),results=await Storage.results();
    final kid=k.where((e)=>e.referenceId==referenceId&&e.area==area).map((e)=>e.id).toSet();
    final tid=tests.where((e)=>e.referenceId==referenceId&&e.area==area).map((e)=>e.id).toSet();
    k.removeWhere((e)=>e.referenceId==referenceId&&e.area==area);
    h.removeWhere((e)=>e.referenceId==referenceId&&e.area==area);
    tests.removeWhere((e)=>(e.referenceId==referenceId&&e.area==area)||kid.contains(e.knowledgeId));
    results.removeWhere((e)=>(e.referenceId==referenceId&&e.area==area)||kid.contains(e.knowledgeId)||tid.contains(e.testId));
    await Future.wait([saveKnowledge(k),saveHistory(h),saveTests(tests),saveResults(results)]);
  }

  static Future<void> rebuildAi(Iterable<_RefLink> source,{String? groupId,String? modelId,String? typeId,String? printId}) async {
    final list=source.toList();
    await clearAiByScope(groupId:groupId,modelId:modelId,typeId:typeId,printId:printId,referenceIds:refIds(list));
    if(list.isEmpty)return;
    final k=await knowledge(),h=await history(),d=now();
    for(final x in list)for(final s in x.reference.scans){
      final content=s.details.trim();if(content.isEmpty)continue;
      final kid=newId();
      k.add(AiKnowledge(id:kid,groupId:x.group.id,modelId:x.model.id,typeId:x.type.id,printId:x.print.id,referenceId:x.reference.id,area:s.area,content:content,createdAt:d,updatedAt:d));
      h.add(AiLearningHistory(id:newId(),groupId:x.group.id,modelId:x.model.id,typeId:x.type.id,printId:x.print.id,referenceId:x.reference.id,area:s.area,content:content,learnedAt:d));
    }
    await Future.wait([saveKnowledge(k),saveHistory(h)]);
  }

  static Future<void> syncGroup(GroupData g)=>rebuildAi(links(g),groupId:g.id);
  static Future<void> syncModel(GroupData g,ModelData m)=>rebuildAi(links(_copyGroup(g,[m])),modelId:m.id);
  static Future<void> syncType(GroupData g,ModelData m,TypeData t)=>rebuildAi(links(_copyGroup(g,[ModelData(id:m.id,name:m.name,createdAt:m.createdAt,updatedAt:m.updatedAt,types:[t])])),typeId:t.id);
  static Future<void> syncPrint(GroupData g,ModelData m,TypeData t,PrintData p)=>rebuildAi(links(_copyGroup(g,[ModelData(id:m.id,name:m.name,createdAt:m.createdAt,updatedAt:m.updatedAt,types:[TypeData(id:t.id,name:t.name,createdAt:t.createdAt,updatedAt:t.updatedAt,prints:[p])])])),printId:p.id);

  static Future<void> syncScan({required GroupData group,required ModelData model,required TypeData type,required PrintData print,required ReferenceData reference,required ScanResult scan}) async {
    await clearAiByArea(reference.id,scan.area);
    final content=scan.details.trim();if(content.isEmpty)return;
    final d=now(),k=await knowledge(),h=await history(),kid=newId();
    k.add(AiKnowledge(id:kid,groupId:group.id,modelId:model.id,typeId:type.id,printId:print.id,referenceId:reference.id,area:scan.area,content:content,createdAt:d,updatedAt:d));
    h.add(AiLearningHistory(id:newId(),groupId:group.id,modelId:model.id,typeId:type.id,printId:print.id,referenceId:reference.id,area:scan.area,content:content,learnedAt:d));
    await Future.wait([saveKnowledge(k),saveHistory(h)]);
  }

  static Future<void> deleteReference(ReferenceData r)=>clearAiByScope(referenceIds:{r.id});
  static Future<void> deletePrint(PrintData p)=>clearAiByScope(printId:p.id,referenceIds:_refsFromPrint(p));
  static Future<void> deleteType(TypeData t)=>clearAiByScope(typeId:t.id,referenceIds:_refsFromType(t));
  static Future<void> deleteModel(ModelData m)=>clearAiByScope(modelId:m.id,referenceIds:_refsFromModel(m));
  static Future<void> deleteGroup(GroupData g)=>clearAiByScope(groupId:g.id,referenceIds:refIds(links(g)));
  static Set<String> _refsFromPrint(PrintData p)=>p.references.map((e)=>e.id).toSet();
  static Set<String> _refsFromType(TypeData t)=>t.prints.expand((p)=>p.references).map((r)=>r.id).toSet();
  static Set<String> _refsFromModel(ModelData m)=>m.types.expand((t)=>t.prints).expand((p)=>p.references).map((r)=>r.id).toSet();
}

GroupData _copyGroup(GroupData g,List<ModelData> models)=>GroupData(id:g.id,name:g.name,temple:g.temple,createdAt:g.createdAt,updatedAt:g.updatedAt,models:models);

class App extends StatelessWidget {
  final List<CameraDescription> cameras;
  const App(this.cameras,{super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'กล้องสแกนพระและเหรียญ',
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.brown),useMaterial3:true),
    home:HomePage(cameras:cameras));
}

class PathBar extends StatelessWidget {
  final String text;const PathBar(this.text,{super.key});
  @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(10),color:Colors.brown.shade50,child:Text(text,style:const TextStyle(fontWeight:FontWeight.bold)));
}

class CreateReferencePage extends StatefulWidget {
  final List<CameraDescription> cameras;const CreateReferencePage({super.key,required this.cameras});
  @override State<CreateReferencePage> createState()=>_CreateReferencePageState();
}
class _CreateReferencePageState extends State<CreateReferencePage>{
  final groupController=TextEditingController(),templeController=TextEditingController(),modelController=TextEditingController(),printController=TextEditingController();
  String selectedType=typeOptions.first;bool saving=false;
  @override void dispose(){groupController.dispose();templeController.dispose();modelController.dispose();printController.dispose();super.dispose();}
  Future<int> nextNumber(List<GroupData> groups) async {
    var max=0;for(final g in groups)for(final x in Storage.links(g)){if(x.reference.referenceNumber>max)max=x.reference.referenceNumber;}return max+1;
  }
  Future<void> create() async {
    final groupName=groupController.text.trim(),temple=templeController.text.trim(),modelName=modelController.text.trim(),printName=printController.text.trim();
    if([groupName,temple,modelName,printName].any((e)=>e.isEmpty)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')));return;}
    if(saving)return;setState(()=>saving=true);
    try{
      final groups=await Storage.groups(),d=now();
      GroupData? group=firstWhereOrNull(groups,(g)=>g.name.trim()==groupName&&g.temple.trim()==temple);
      if(group==null){group=GroupData(id:newId(),name:groupName,temple:temple,createdAt:d,updatedAt:d);groups.add(group);}
      ModelData? model=firstWhereOrNull(group.models,(m)=>m.name.trim()==modelName);
      if(model==null){model=ModelData(id:newId(),name:modelName,createdAt:d,updatedAt:d);group.models.add(model);}
      TypeData? type=firstWhereOrNull(model.types,(t)=>t.name.trim()==selectedType);
      if(type==null){type=TypeData(id:newId(),name:selectedType,createdAt:d,updatedAt:d);model.types.add(type);}
      PrintData? print=firstWhereOrNull(type.prints,(p)=>p.name.trim()==printName);
      if(print==null){print=PrintData(id:newId(),name:printName,createdAt:d,updatedAt:d);type.prints.add(print);}
      final reference=ReferenceData(id:newId(),referenceNumber:await nextNumber(groups),createdAt:d,updatedAt:d);
      print.references.add(reference);group.updatedAt=d;model.updatedAt=d;type.updatedAt=d;print.updatedAt=d;
      await Storage.saveGroups(groups);if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>ReferenceEditPage(cameras:widget.cameras,group:group!,model:model!,type:type!,print:print!,reference:reference)));
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('ไม่สามารถสร้างข้อมูลได้: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('สร้างองค์อ้างอิง')),body:ListView(padding:const EdgeInsets.all(12),children:[
    const PathBar('กรอกข้อมูลเพื่อสร้างองค์อ้างอิง'),const SizedBox(height:12),
    TextField(controller:groupController,decoration:const InputDecoration(labelText:'ชื่อกลุ่ม',border:OutlineInputBorder())),const SizedBox(height:12),
    TextField(controller:templeController,decoration:const InputDecoration(labelText:'วัด',border:OutlineInputBorder())),const SizedBox(height:12),
    TextField(controller:modelController,decoration:const InputDecoration(labelText:'รุ่น',border:OutlineInputBorder())),const SizedBox(height:12),
    DropdownButtonFormField<String>(value:selectedType,isExpanded:true,decoration:const InputDecoration(labelText:'ชนิด',border:OutlineInputBorder()),items:typeOptions.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setState(()=>selectedType=v);}),const SizedBox(height:12),
    TextField(controller:printController,decoration:const InputDecoration(labelText:'พิมพ์',border:OutlineInputBorder())),const SizedBox(height:20),
    SizedBox(width:double.infinity,height:52,child:ElevatedButton.icon(onPressed:saving?null:create,icon:saving?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.add),label:Text(saving?'กำลังสร้าง...':'สร้างองค์อ้างอิง'))),
  ]));
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;const HomePage({super.key,required this.cameras});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  List<GroupData> data=[];
  @override void initState(){super.initState();load();}
  Future<void> load() async {data=await Storage.groups();if(mounted)setState((){});}
  Future<void> createGroup() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>CreateReferencePage(cameras:widget.cameras)));if(mounted)load();}
  Future<void> editGroup(GroupData g) async {
    final name=TextEditingController(text:g.name),temple=TextEditingController(text:g.temple);
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('แก้ไขกลุ่ม'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'ชื่อกลุ่ม')),const SizedBox(height:10),
      TextField(controller:temple,decoration:const InputDecoration(labelText:'วัด'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('ยกเลิก')),ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:const Text('บันทึก'))]));
    if(ok==true&&name.text.trim().isNotEmpty){g.name=name.text.trim();g.temple=temple.text.trim();g.updatedAt=now();await Storage.saveGroup(g);await Storage.syncGroup(g);await load();}
    name.dispose();temple.dispose();
  }
  Future<void> deleteGroup(GroupData g) async {
    if(!await confirmDelete(context,g.name))return;
    final ids=Storage.refIds(Storage.links(g));data.removeWhere((e)=>e.id==g.id);await Storage.saveGroups(data);await Storage.clearAiByScope(groupId:g.id,referenceIds:ids);await load();
  }
  int countReferences(GroupData g)=>g.models.fold(0,(a,m)=>a+m.types.fold(0,(b,t)=>b+t.prints.fold(0,(c,p)=>c+p.references.length)));
  int countScans(GroupData g)=>g.models.fold(0,(a,m)=>a+m.types.fold(0,(b,t)=>b+t.prints.fold(0,(c,p)=>c+p.references.fold(0,(d,r)=>d+r.scans.length))));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('กล้องสแกนพระและเหรียญ')),floatingActionButton:FloatingActionButton.extended(onPressed:createGroup,label:const Text('สร้างองค์อ้างอิง'),icon:const Icon(Icons.add)),body:Column(children:[
    const PathBar('ฐานข้อมูลส่วนตัว'),Expanded(child:data.isEmpty?const Center(child:Text('ยังไม่มีข้อมูล')):ListView.builder(itemCount:data.length,itemBuilder:(_,i){final g=data[i];return Card(margin:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:ListTile(
      title:Text(g.name,style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${g.temple.isEmpty?'':'วัด ${g.temple}\n'}องค์อ้างอิง ${countReferences(g)} • สแกน ${countScans(g)}'),
      onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ModelPage(cameras:widget.cameras,group:g))).then((_)=>load()),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>editGroup(g),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>deleteGroup(g),icon:const Icon(Icons.delete))])));}))]));
}

class ModelPage extends StatefulWidget {
  final List<CameraDescription> cameras;final GroupData group;const ModelPage({super.key,required this.cameras,required this.group});
  @override State<ModelPage> createState()=>_ModelPageState();
}
class _ModelPageState extends State<ModelPage>{
  Future<void> add() async {await textDialog(context,'เพิ่มรุ่น','',(v)async{final d=now();widget.group.models.add(ModelData(id:newId(),name:v,createdAt:d,updatedAt:d));widget.group.updatedAt=d;await Storage.saveGroup(widget.group);});if(mounted)setState((){});}
  Future<void> edit(ModelData m) async {await textDialog(context,'แก้ไขรุ่น',m.name,(v)async{m.name=v;m.updatedAt=now();widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.syncModel(widget.group,m);});if(mounted)setState((){});}
  Future<void> delete(ModelData m) async {if(!await confirmDelete(context,m.name))return;final ids=m.types.expand((t)=>t.prints).expand((p)=>p.references).map((r)=>r.id).toSet();widget.group.models.removeWhere((e)=>e.id==m.id);widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.clearAiByScope(modelId:m.id,referenceIds:ids);if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.group.name)),floatingActionButton:FloatingActionButton.extended(onPressed:add,label:const Text('เพิ่มรุ่น'),icon:const Icon(Icons.add)),body:Column(children:[
    PathBar('${widget.group.name} > รุ่น'),Expanded(child:widget.group.models.isEmpty?const Center(child:Text('ยังไม่มีรุ่น')):ListView.builder(itemCount:widget.group.models.length,itemBuilder:(_,i){final m=widget.group.models[i];return Card(child:ListTile(title:Text(m.name),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TypePage(cameras:widget.cameras,group:widget.group,model:m))).then((_)=>mounted?setState((){}):null),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>edit(m),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>delete(m),icon:const Icon(Icons.delete))])));})),
  ]));
}

class TypePage extends StatefulWidget {
  final List<CameraDescription> cameras;final GroupData group;final ModelData model;const TypePage({super.key,required this.cameras,required this.group,required this.model});
  @override State<TypePage> createState()=>_TypePageState();
}
class _TypePageState extends State<TypePage>{
  Future<void> add() async {
    String selected=typeOptions.first;
    final ok=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('เพิ่มชนิด'),content:DropdownButtonFormField<String>(value:selected,isExpanded:true,items:typeOptions.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>set(()=>selected=v??selected)),actions:[
      TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ยกเลิก')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('บันทึก'))])));
    if(ok==true){final d=now();widget.model.types.add(TypeData(id:newId(),name:selected,createdAt:d,updatedAt:d));widget.group.updatedAt=d;await Storage.saveGroup(widget.group);if(mounted)setState((){});}
  }
  Future<void> edit(TypeData t) async {
    String selected=t.name;
    final ok=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('แก้ไขชนิด'),content:DropdownButtonFormField<String>(value:typeOptions.contains(selected)?selected:typeOptions.first,isExpanded:true,items:typeOptions.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>set(()=>selected=v??selected)),actions:[
      TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ยกเลิก')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('บันทึก'))])));
    if(ok==true&&selected!=t.name){t.name=selected;t.updatedAt=now();widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.syncType(widget.group,widget.model,t);}
    if(mounted)setState((){});
  }
  Future<void> delete(TypeData t) async {if(!await confirmDelete(context,t.name))return;final ids=t.prints.expand((p)=>p.references).map((r)=>r.id).toSet();widget.model.types.removeWhere((e)=>e.id==t.id);widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.clearAiByScope(typeId:t.id,referenceIds:ids);if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.model.name)),floatingActionButton:FloatingActionButton.extended(onPressed:add,label:const Text('เพิ่มชนิด'),icon:const Icon(Icons.add)),body:Column(children:[
    PathBar('${widget.group.name} > ${widget.model.name} > ชนิด'),Expanded(child:widget.model.types.isEmpty?const Center(child:Text('ยังไม่มีชนิด')):ListView.builder(itemCount:widget.model.types.length,itemBuilder:(_,i){final t=widget.model.types[i];return Card(child:ListTile(title:Text(t.name),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PrintPage(cameras:widget.cameras,group:widget.group,model:widget.model,type:t))).then((_)=>mounted?setState((){}):null),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>edit(t),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>delete(t),icon:const Icon(Icons.delete))])));})),
  ]));
}

class PrintPage extends StatefulWidget {
  final List<CameraDescription> cameras;final GroupData group;final ModelData model;final TypeData type;const PrintPage({super.key,required this.cameras,required this.group,required this.model,required this.type});
  @override State<PrintPage> createState()=>_PrintPageState();
}
class _PrintPageState extends State<PrintPage>{
  Future<void> add() async {await textDialog(context,'เพิ่มพิมพ์','',(v)async{final d=now();widget.type.prints.add(PrintData(id:newId(),name:v,createdAt:d,updatedAt:d));widget.group.updatedAt=d;await Storage.saveGroup(widget.group);});if(mounted)setState((){});}
  Future<void> edit(PrintData p) async {await textDialog(context,'แก้ไขพิมพ์',p.name,(v)async{p.name=v;p.updatedAt=now();widget.type.updatedAt=now();widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.syncPrint(widget.group,widget.model,widget.type,p);});if(mounted)setState((){});}
  Future<void> delete(PrintData p) async {if(!await confirmDelete(context,p.name))return;final ids=p.references.map((r)=>r.id).toSet();widget.type.prints.removeWhere((e)=>e.id==p.id);widget.type.updatedAt=now();widget.group.updatedAt=now();await Storage.saveGroup(widget.group);await Storage.clearAiByScope(printId:p.id,referenceIds:ids);if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.type.name)),floatingActionButton:FloatingActionButton.extended(onPressed:add,label:const Text('เพิ่มพิมพ์'),icon:const Icon(Icons.add)),body:Column(children:[
    PathBar('${widget.group.name} > ${widget.model.name} > ${widget.type.name} > พิมพ์'),Expanded(child:widget.type.prints.isEmpty?const Center(child:Text('ยังไม่มีพิมพ์')):ListView.builder(itemCount:widget.type.prints.length,itemBuilder:(_,i){final p=widget.type.prints[i];return Card(child:ListTile(title:Text(p.name),subtitle:Text('องค์อ้างอิง ${p.references.length}'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReferencePage(cameras:widget.cameras,group:widget.group,model:widget.model,type:widget.type,print:p))).then((_)=>mounted?setState((){}):null),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>edit(p),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>delete(p),icon:const Icon(Icons.delete))])));})),
  ]));
}

class ReferencePage extends StatefulWidget {
  final List<CameraDescription> cameras;final GroupData group;final ModelData model;final TypeData type;final PrintData print;
  const ReferencePage({super.key,required this.cameras,required this.group,required this.model,required this.type,required this.print});
  @override State<ReferencePage> createState()=>_ReferencePageState();
}
class _ReferencePageState extends State<ReferencePage>{
  Future<int> nextNumber() async {
    final gs=await Storage.groups();var max=0;
    for(final g in gs)for(final x in Storage.links(g)){if(x.reference.referenceNumber>max)max=x.reference.referenceNumber;}
    return max+1;
  }
  Future<void> addReference() async {
    final n=await nextNumber(),d=now();
    widget.print.references.add(ReferenceData(id:newId(),referenceNumber:n,createdAt:d,updatedAt:d));
    widget.print.updatedAt=d;widget.type.updatedAt=d;widget.model.updatedAt=d;widget.group.updatedAt=d;
    await Storage.saveGroup(widget.group);if(mounted)setState((){});
  }
  Future<void> editReference(ReferenceData r) async {
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>ReferenceEditPage(cameras:widget.cameras,group:widget.group,model:widget.model,type:widget.type,print:widget.print,reference:r)));
    if(mounted)setState((){});
  }
  Future<void> deleteReference(ReferenceData r) async {
    if(!await confirmDelete(context,'องค์อ้างอิง #${r.referenceNumber}'))return;
    widget.print.references.removeWhere((e)=>e.id==r.id);widget.print.updatedAt=now();widget.group.updatedAt=now();
    await Storage.saveGroup(widget.group);await Storage.clearAiByScope(referenceIds:{r.id});if(mounted)setState((){});
  }
  String status(ReferenceData r){
    final areas=scanAreasForType(widget.type.name);
    final done=areas.where((a)=>r.scans.any((s)=>s.area==a&&s.details.trim().isNotEmpty)).length;
    return '$done/${areas.length} ด้าน';
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.print.name)),floatingActionButton:FloatingActionButton.extended(onPressed:addReference,label:const Text('เพิ่มองค์อ้างอิง'),icon:const Icon(Icons.add)),body:Column(children:[
    PathBar('${widget.group.name} > ${widget.model.name} > ${widget.type.name} > ${widget.print.name}'),Expanded(child:widget.print.references.isEmpty?const Center(child:Text('ยังไม่มีองค์อ้างอิง')):ListView.builder(itemCount:widget.print.references.length,itemBuilder:(_,i){final r=widget.print.references[i];return Card(margin:const EdgeInsets.symmetric(horizontal:8,vertical:4),child:ExpansionTile(
      title:Text('องค์อ้างอิง #${r.referenceNumber}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(status(r)),
      children:[...scanAreasForType(widget.type.name).map((a){final s=firstWhereOrNull(r.scans,(e)=>e.area==a);return ListTile(title:Text(a),subtitle:Text(s==null||s.details.trim().isEmpty?'ยังไม่มีข้อมูล':'มีข้อมูลแล้ว'));}),
      Row(mainAxisAlignment:MainAxisAlignment.end,children:[ElevatedButton.icon(onPressed:()=>editReference(r),icon:const Icon(Icons.edit),label:const Text('แก้ไข')),const SizedBox(width:8),IconButton(onPressed:()=>deleteReference(r),icon:const Icon(Icons.delete))]),const SizedBox(height:8)]));})),
    Padding(padding:const EdgeInsets.all(10),child:SizedBox(width:double.infinity,child:OutlinedButton(onPressed:()=>Navigator.popUntil(context,(route)=>route.isFirst),child:const Text('กลับหน้ากลุ่ม')))),
  ]));
}

class ReferenceEditPage extends StatefulWidget {
  final List<CameraDescription> cameras;final GroupData group;final ModelData model;final TypeData type;final PrintData print;final ReferenceData reference;
  const ReferenceEditPage({super.key,required this.cameras,required this.group,required this.model,required this.type,required this.print,required this.reference});
  @override State<ReferenceEditPage> createState()=>_ReferenceEditPageState();
}
class _ReferenceEditPageState extends State<ReferenceEditPage>{
  ScanResult? getScan(String area)=>firstWhereOrNull(widget.reference.scans,(s)=>s.area==area);
  Future<void> scanArea(String area) async {
    final r=await Navigator.push<ScanResult>(context,MaterialPageRoute(builder:(_)=>ScanPage(cameras:widget.cameras,area:area,group:widget.group,model:widget.model,type:widget.type,print:widget.print,reference:widget.reference)));
    if(r==null)return;
    final old=getScan(area);if(old==null)widget.reference.scans.add(r);else old.details=r.details;
    widget.reference.updatedAt=now();widget.group.updatedAt=now();await Storage.saveGroup(widget.group);
    await Storage.syncScan(group:widget.group,model:widget.model,type:widget.type,print:widget.print,reference:widget.reference,scan:r);
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context){
    final areas=scanAreasForType(widget.type.name);
    return Scaffold(appBar:AppBar(title:Text('องค์อ้างอิง #${widget.reference.referenceNumber}')),body:Column(children:[
      PathBar('${widget.group.name} > ${widget.model.name} > ${widget.type.name} > ${widget.print.name}'),
      Expanded(child:ListView(padding:const EdgeInsets.all(10),children:[
        Text('องค์อ้างอิง #${widget.reference.referenceNumber}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),
        ...areas.map((area){final s=getScan(area),has=s!=null&&s.details.trim().isNotEmpty;return Card(child:ListTile(title:Text(area),subtitle:Text(has?'มีข้อมูลสแกนแล้ว':'ยังไม่มีข้อมูล'),trailing:ElevatedButton(onPressed:()=>scanArea(area),child:Text(has?'แก้ไข':'สแกน'))));}),
      ])),
    ]));
  }
}

class ScanPage extends StatelessWidget {
  final List<CameraDescription> cameras;final String area;final GroupData group;final ModelData model;final TypeData type;final PrintData print;final ReferenceData reference;
  const ScanPage({super.key,required this.cameras,required this.area,required this.group,required this.model,required this.type,required this.print,required this.reference});
  Future<void> gallery(BuildContext context) async {
    final f=await ImagePicker().pickImage(source:ImageSource.gallery);if(f==null)return;
    File? temp;
    try{
      temp=File('${Directory.systemTemp.path}/amulet_scan_${newId()}.jpg');await File(f.path).copy(temp.path);
      final r=await Navigator.push<ScanResult>(context,MaterialPageRoute(builder:(_)=>AiVisionPage(imageFile:XFile(temp!.path),area:area,group:group,model:model,type:type,print:print,reference:reference)));
      if(r!=null&&context.mounted)Navigator.pop(context,r);
    }finally{try{if(temp!=null&&await temp.exists())await temp.delete();}catch(_){}} 
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('สแกน $area')),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    const Icon(Icons.camera_alt,size:70),const SizedBox(height:20),
    ElevatedButton.icon(onPressed:cameras.isEmpty?null:()async{final r=await Navigator.push<ScanResult>(context,MaterialPageRoute(builder:(_)=>CameraScanPage(cameras:cameras,area:area,group:group,model:model,type:type,print:print,reference:reference)));if(r!=null&&context.mounted)Navigator.pop(context,r);},icon:const Icon(Icons.camera),label:const Text('เปิดกล้อง')),
    const SizedBox(height:10),OutlinedButton.icon(onPressed:()=>gallery(context),icon:const Icon(Icons.photo_library),label:const Text('เลือกจาก Gallery')),const SizedBox(height:20),
    const Padding(padding:EdgeInsets.all(20),child:Text('ภาพใช้ชั่วคราวเพื่อวิเคราะห์เท่านั้น\nแอปจะไม่เก็บรูปไว้ในฐานข้อมูล',textAlign:TextAlign.center)),
  ]));
}

class CameraScanPage extends StatefulWidget {
  final List<CameraDescription> cameras;final String area;final GroupData group;final ModelData model;final TypeData type;final PrintData print;final ReferenceData reference;
  const CameraScanPage({super.key,required this.cameras,required this.area,required this.group,required this.model,required this.type,required this.print,required this.reference});
  @override State<CameraScanPage> createState()=>_CameraScanPageState();
}
class _CameraScanPageState extends State<CameraScanPage>{
  CameraController? controller;Future<void>? initializeFuture;bool busy=false;
  @override void initState(){super.initState();controller=CameraController(widget.cameras.first,ResolutionPreset.high,enableAudio:false);initializeFuture=controller!.initialize();}
  @override void dispose(){controller?.dispose();super.dispose();}
  Future<void> take() async {
    final c=controller;if(busy||c==null||!c.value.isInitialized)return;setState(()=>busy=true);XFile? file;
    try{
      file=await c.takePicture();
      final r=await Navigator.push<ScanResult>(context,MaterialPageRoute(builder:(_)=>AiVisionPage(imageFile:file!,area:widget.area,group:widget.group,model:widget.model,type:widget.type,print:widget.print,reference:widget.reference)));
      if(r!=null&&mounted)Navigator.pop(context,r);
    }finally{try{if(file!=null){final f=File(file.path);if(await f.exists())await f.delete();}}catch(_){ }if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final c=controller;if(c==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(appBar:AppBar(title:Text('กล้อง - ${widget.area}')),body:FutureBuilder<void>(future:initializeFuture,builder:(_,snap){
      if(snap.connectionState!=ConnectionState.done||!c.value.isInitialized)return const Center(child:CircularProgressIndicator());
      return Stack(fit:StackFit.expand,children:[CameraPreview(c),Positioned(bottom:30,left:0,right:0,child:Center(child:FloatingActionButton(onPressed:busy?null:take,child:const Icon(Icons.camera))))]);
    }));
  }
}

class AiVisionPage extends StatefulWidget {
  final XFile imageFile;final String area;final GroupData group;final ModelData model;final TypeData type;final PrintData print;final ReferenceData reference;
  const AiVisionPage({super.key,required this.imageFile,required this.area,required this.group,required this.model,required this.type,required this.print,required this.reference});
  @override State<AiVisionPage> createState()=>_AiVisionPageState();
}
class _AiVisionPageState extends State<AiVisionPage>{
  final controllers=<String,TextEditingController>{};
  @override void initState(){super.initState();for(final h in aiHeads){controllers[h]=TextEditingController();}
    final old=firstWhereOrNull(widget.reference.scans,(e)=>e.area==widget.area);
    if(old!=null){final lines=old.details.split('\n');for(final h in aiHeads){final line=firstWhereOrNull(lines,(e)=>e.startsWith('$h:'));if(line!=null)controllers[h]!.text=line.substring(h.length+1).trim();}
      if(lines.isNotEmpty&&controllers.values.every((e)=>e.text.trim().isEmpty))controllers[aiHeads.first]!.text=old.details;
    }
  }
  @override void dispose(){for(final c in controllers.values)c.dispose();super.dispose();}
  String buildDetails(){final out=<String>[];for(final h in aiHeads){final v=controllers[h]!.text.trim();if(v.isNotEmpty)out.add('$h: $v');}return out.join('\n');}
  void save()=>Navigator.pop(context,ScanResult(area:widget.area,details:buildDetails()));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('รายละเอียด ${widget.area}')),body:ListView(padding:const EdgeInsets.all(10),children:[
    Image.file(File(widget.imageFile.path),height:260,fit:BoxFit.contain),const SizedBox(height:10),
    ...aiHeads.map((h)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:controllers[h],maxLines:3,decoration:InputDecoration(labelText:h,border:const OutlineInputBorder())))),
    const SizedBox(height:10),SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('บันทึกข้อมูล'))),const SizedBox(height:20),
  ]));
}
