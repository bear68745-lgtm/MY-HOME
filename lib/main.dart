import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(await availableCameras()));
}

const areas=['ด้านหน้า','ด้านหลัง','ด้านข้าง','ก้นพระ'];
const typeOptions=[
  'เหรียญ','เหรียญหล่อ','พระสมเด็จ','รูปหล่อ','พระกริ่ง',
  'พระปิดตาเนื้อผง/หว้าน','พระปิดตาเนื้อโลหะ','พระเนื้อผง','พระเนื้อดิน',
  'นางพญา','ผงสุพรรณ','พระรอด','พระซุ้มกอ','พระขุนแผน',
  'หลวงปู่ทวดเนื้อหว้าน','หลวงปู่ทวดหลังเตารีด','เขี้ยวแกะ','งาแกะ',
  'ตะกรุด','อื่น ๆ'
];

String newId()=>DateTime.now().microsecondsSinceEpoch.toString();

class ScanResult{
  String area,details;
  ScanResult({required this.area,this.details=''});

  Map<String,dynamic> toMap()=>{'area':area,'details':details};

  factory ScanResult.fromMap(Map<String,dynamic> m)=>ScanResult(
    area:m['area']??'',details:m['details']??'');
}

class ReferenceData{
  String id;
  int referenceNumber;
  DateTime createdAt,updatedAt;
  List<ScanResult> scans;

  ReferenceData({
    required this.id,required this.referenceNumber,
    required this.createdAt,DateTime? updatedAt,List<ScanResult>? scans,
  }):updatedAt=updatedAt??createdAt,scans=scans??[];

  Map<String,dynamic> toMap()=> {
    'id':id,'referenceNumber':referenceNumber,
    'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
    'scans':scans.map((e)=>e.toMap()).toList(),
  };

  factory ReferenceData.fromMap(Map<String,dynamic> m)=>ReferenceData(
    id:m['id']??newId(),
    referenceNumber:m['referenceNumber']??1,
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now(),
    scans:(m['scans'] as List???[])
      .map((e)=>ScanResult.fromMap(Map<String,dynamic>.from(e))).toList());

  ReferenceData copyWith({int? referenceNumber,List<ScanResult>? scans})=>
    ReferenceData(
      id:id,referenceNumber:referenceNumber??this.referenceNumber,
      createdAt:createdAt,updatedAt:DateTime.now(),
      scans:scans??this.scans);
}

/* =========================
   AI DATA
   ========================= */

class AiKnowledge{
  String id,groupId,modelId,typeId,printId,referenceId,area,content;
  DateTime createdAt,updatedAt;

  AiKnowledge({
    required this.id,required this.groupId,required this.modelId,
    required this.typeId,required this.printId,required this.referenceId,
    required this.area,required this.content,required this.createdAt,
    DateTime? updatedAt,
  }):updatedAt=updatedAt??createdAt;

  Map<String,dynamic> toMap()=> {
    'id':id,'groupId':groupId,'modelId':modelId,'typeId':typeId,
    'printId':printId,'referenceId':referenceId,'area':area,
    'content':content,'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
  };

  factory AiKnowledge.fromMap(Map<String,dynamic> m)=>AiKnowledge(
    id:m['id']??newId(),groupId:m['groupId']??'',
    modelId:m['modelId']??'',typeId:m['typeId']??'',
    printId:m['printId']??'',referenceId:m['referenceId']??'',
    area:m['area']??'',content:m['content']??'',
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now());
}

class AiLearningHistory{
  String id,groupId,modelId,typeId,printId,referenceId,area,content;
  DateTime learnedAt;

  AiLearningHistory({
    required this.id,required this.groupId,required this.modelId,
    required this.typeId,required this.printId,required this.referenceId,
    required this.area,required this.content,required this.learnedAt});

  Map<String,dynamic> toMap()=> {
    'id':id,'groupId':groupId,'modelId':modelId,'typeId':typeId,
    'printId':printId,'referenceId':referenceId,'area':area,
    'content':content,'learnedAt':learnedAt.toIso8601String(),
  };

  factory AiLearningHistory.fromMap(Map<String,dynamic> m)=>
    AiLearningHistory(
      id:m['id']??newId(),groupId:m['groupId']??'',
      modelId:m['modelId']??'',typeId:m['typeId']??'',
      printId:m['printId']??'',referenceId:m['referenceId']??'',
      area:m['area']??'',content:m['content']??'',
      learnedAt:DateTime.tryParse(m['learnedAt']??'')??DateTime.now());
}

class AiMemoryTest{
  String id,knowledgeId,referenceId,area,question,answer;
  DateTime testedAt;

  AiMemoryTest({
    required this.id,required this.knowledgeId,required this.referenceId,
    required this.area,required this.question,required this.answer,
    required this.testedAt});

  Map<String,dynamic> toMap()=> {
    'id':id,'knowledgeId':knowledgeId,'referenceId':referenceId,
    'area':area,'question':question,'answer':answer,
    'testedAt':testedAt.toIso8601String(),
  };

  factory AiMemoryTest.fromMap(Map<String,dynamic> m)=>AiMemoryTest(
    id:m['id']??newId(),knowledgeId:m['knowledgeId']??'',
    referenceId:m['referenceId']??'',area:m['area']??'',
    question:m['question']??'',answer:m['answer']??'',
    testedAt:DateTime.tryParse(m['testedAt']??'')??DateTime.now());
}

class AiTestResult{
  String id,testId,knowledgeId,referenceId,area,mode,result,
      answer,referenceAnswer,reason;
  DateTime checkedAt;

  AiTestResult({
    required this.id,required this.testId,required this.knowledgeId,
    required this.referenceId,required this.area,required this.mode,
    required this.result,required this.answer,
    required this.referenceAnswer,required this.reason,
    required this.checkedAt});

  Map<String,dynamic> toMap()=> {
    'id':id,'testId':testId,'knowledgeId':knowledgeId,
    'referenceId':referenceId,'area':area,'mode':mode,
    'result':result,'answer':answer,
    'referenceAnswer':referenceAnswer,'reason':reason,
    'checkedAt':checkedAt.toIso8601String(),
  };

  factory AiTestResult.fromMap(Map<String,dynamic> m)=>AiTestResult(
    id:m['id']??newId(),testId:m['testId']??'',
    knowledgeId:m['knowledgeId']??'',referenceId:m['referenceId']??'',
    area:m['area']??'',mode:m['mode']??'',result:m['result']??'',
    answer:m['answer']??'',referenceAnswer:m['referenceAnswer']??'',
    reason:m['reason']??'',
    checkedAt:DateTime.tryParse(m['checkedAt']??'')??DateTime.now());
}

/* =========================
   MAIN DATA
   ========================= */

class PrintData{
  String id,name;
  DateTime createdAt,updatedAt;
  List<ReferenceData> references;

  PrintData({
    required this.id,required this.name,required this.createdAt,
    DateTime? updatedAt,List<ReferenceData>? references,
  }):updatedAt=updatedAt??createdAt,references=references??[];

  Map<String,dynamic> toMap()=> {
    'id':id,'name':name,'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
    'references':references.map((e)=>e.toMap()).toList(),
  };

  factory PrintData.fromMap(Map<String,dynamic> m)=>PrintData(
    id:m['id']??newId(),name:m['name']??'พิมพ์เดียว',
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now(),
    references:(m['references'] as List???[])
      .map((e)=>ReferenceData.fromMap(Map<String,dynamic>.from(e))).toList());
}

class TypeData{
  String id,name;
  DateTime createdAt,updatedAt;
  List<PrintData> prints;

  TypeData({
    required this.id,required this.name,required this.createdAt,
    DateTime? updatedAt,List<PrintData>? prints,
  }):updatedAt=updatedAt??createdAt,prints=prints??[];

  Map<String,dynamic> toMap()=> {
    'id':id,'name':name,'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
    'prints':prints.map((e)=>e.toMap()).toList(),
  };

  factory TypeData.fromMap(Map<String,dynamic> m)=>TypeData(
    id:m['id']??newId(),name:m['name']??'',
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now(),
    prints:(m['prints'] as List???[])
      .map((e)=>PrintData.fromMap(Map<String,dynamic>.from(e))).toList());
}

class ModelData{
  String id,name;
  DateTime createdAt,updatedAt;
  List<TypeData> types;

  ModelData({
    required this.id,required this.name,required this.createdAt,
    DateTime? updatedAt,List<TypeData>? types,
  }):updatedAt=updatedAt??createdAt,types=types??[];

  Map<String,dynamic> toMap()=> {
    'id':id,'name':name,'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
    'types':types.map((e)=>e.toMap()).toList(),
  };

  factory ModelData.fromMap(Map<String,dynamic> m)=>ModelData(
    id:m['id']??newId(),name:m['name']??'',
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now(),
    types:(m['types'] as List???[])
      .map((e)=>TypeData.fromMap(Map<String,dynamic>.from(e))).toList());
}

class GroupData{
  String id,name,temple;
  DateTime createdAt,updatedAt;
  List<ModelData> models;

  GroupData({
    required this.id,required this.name,required this.temple,
    required this.createdAt,DateTime? updatedAt,List<ModelData>? models,
  }):updatedAt=updatedAt??createdAt,models=models??[];

  Map<String,dynamic> toMap()=> {
    'id':id,'name':name,'temple':temple,
    'createdAt':createdAt.toIso8601String(),
    'updatedAt':updatedAt.toIso8601String(),
    'models':models.map((e)=>e.toMap()).toList(),
  };

  factory GroupData.fromMap(Map<String,dynamic> m)=>GroupData(
    id:m['id']??newId(),name:m['name']??'',temple:m['temple']??'',
    createdAt:DateTime.tryParse(m['createdAt']??'')??DateTime.now(),
    updatedAt:DateTime.tryParse(m['updatedAt']??'')??DateTime.now(),
    models:(m['models'] as List???[])
      .map((e)=>ModelData.fromMap(Map<String,dynamic>.from(e))).toList());
}

/* =========================
   STORAGE
   ========================= */

class Storage{
  static const key='reference_groups';
  static const aiKey='ai_knowledge';
  static const historyKey='ai_learning_history';
  static const testKey='ai_memory_tests';
  static const resultKey='ai_test_results';

  static Future<List<GroupData>> load()async{
    final p=await SharedPreferences.getInstance();
    final r=p.getString(key);
    if(r==null||r.isEmpty)return[];
    try{return(jsonDecode(r)as List)
      .map((e)=>GroupData.fromMap(Map<String,dynamic>.from(e))).toList();}
    catch(_){return[];}
  }

  static Future<void> save(List<GroupData> g)async{
    final p=await SharedPreferences.getInstance();
    await p.setString(key,jsonEncode(g.map((e)=>e.toMap()).toList()));
  }

  static Future<List<AiKnowledge>> loadAi()async{
    final p=await SharedPreferences.getInstance();
    final r=p.getString(aiKey);
    if(r==null||r.isEmpty)return[];
    try{return(jsonDecode(r)as List)
      .map((e)=>AiKnowledge.fromMap(Map<String,dynamic>.from(e))).toList();}
    catch(_){return[];}
  }

  static Future<void> saveAi(List<AiKnowledge> x)async{
    final p=await SharedPreferences.getInstance();
    await p.setString(aiKey,jsonEncode(x.map((e)=>e.toMap()).toList()));
  }

  static Future<List<AiLearningHistory>> loadHistory()async{
    final p=await SharedPreferences.getInstance();
    final r=p.getString(historyKey);
    if(r==null||r.isEmpty)return[];
    try{return(jsonDecode(r)as List)
      .map((e)=>AiLearningHistory.fromMap(
        Map<String,dynamic>.from(e))).toList();}
    catch(_){return[];}
  }

  static Future<void> saveHistory(List<AiLearningHistory> x)async{
    final p=await SharedPreferences.getInstance();
    await p.setString(historyKey,jsonEncode(x.map((e)=>e.toMap()).toList()));
  }

  static Future<List<AiMemoryTest>> loadTests()async{
    final p=await SharedPreferences.getInstance();
    final r=p.getString(testKey);
    if(r==null||r.isEmpty)return[];
    try{return(jsonDecode(r)as List)
      .map((e)=>AiMemoryTest.fromMap(
        Map<String,dynamic>.from(e))).toList();}
    catch(_){return[];}
  }

  static Future<void> saveTests(List<AiMemoryTest> x)async{
    final p=await SharedPreferences.getInstance();
    await p.setString(testKey,jsonEncode(x.map((e)=>e.toMap()).toList()));
  }

  static Future<void> addTest(AiMemoryTest x)async{
    final a=await loadTests();a.add(x);await saveTests(a);
  }

  static Future<List<AiTestResult>> loadResults()async{
    final p=await SharedPreferences.getInstance();
    final r=p.getString(resultKey);
    if(r==null||r.isEmpty)return[];
    try{return(jsonDecode(r)as List)
      .map((e)=>AiTestResult.fromMap(
        Map<String,dynamic>.from(e))).toList();}
    catch(_){return[];}
  }

  static Future<void> saveResults(List<AiTestResult> x)async{
    final p=await SharedPreferences.getInstance();
    await p.setString(resultKey,jsonEncode(x.map((e)=>e.toMap()).toList()));
  }

  static Future<void> addResult(AiTestResult x)async{
    final a=await loadResults();a.add(x);await saveResults(a);
  }

  static Future<void> addAi({
    required GroupData group,required ModelData model,
    required TypeData type,required PrintData print,
    required ReferenceData reference,required ScanResult scan,
  })async{
    final text=scan.details.trim();
    if(text.isEmpty||text.startsWith('รอระบบ AI'))return;

    final now=DateTime.now();
    final list=await loadAi();
    final i=list.indexWhere(
      (e)=>e.referenceId==reference.id&&e.area==scan.area);

    final k=AiKnowledge(
      id:i<0?newId():list[i].id,
      groupId:group.id,modelId:model.id,typeId:type.id,
      printId:print.id,referenceId:reference.id,
      area:scan.area,content:text,
      createdAt:i<0?now:list[i].createdAt,updatedAt:now);

    if(i<0)list.add(k);else list[i]=k;
    await saveAi(list);

    final h=await loadHistory();
    h.add(AiLearningHistory(
      id:newId(),groupId:group.id,modelId:model.id,typeId:type.id,
      printId:print.id,referenceId:reference.id,area:scan.area,
      content:text,learnedAt:now));
    await saveHistory(h);
  }

  static Future<void> correctAi({
    required AiKnowledge old,
    required String content,
  })async{
    final text=content.trim();
    if(text.isEmpty)return;

    final list=await loadAi();
    final i=list.indexWhere((e)=>e.id==old.id);
    if(i<0)return;

    final now=DateTime.now();
    list[i]=AiKnowledge(
      id:old.id,groupId:old.groupId,modelId:old.modelId,
      typeId:old.typeId,printId:old.printId,
      referenceId:old.referenceId,area:old.area,
      content:text,createdAt:old.createdAt,updatedAt:now);
    await saveAi(list);

    final h=await loadHistory();
    h.add(AiLearningHistory(
      id:newId(),groupId:old.groupId,modelId:old.modelId,
      typeId:old.typeId,printId:old.printId,
      referenceId:old.referenceId,area:old.area,
      content:text,learnedAt:now));
    await saveHistory(h);
  }

  static Future<void> deleteAiBy({
    String? groupId,String? modelId,String? typeId,
    String? printId,String? referenceId,String? area,
  })async{
    final a=await loadAi();
    a.removeWhere((e)=>
      (groupId==null||e.groupId==groupId)&&
      (modelId==null||e.modelId==modelId)&&
      (typeId==null||e.typeId==typeId)&&
      (printId==null||e.printId==printId)&&
      (referenceId==null||e.referenceId==referenceId)&&
      (area==null||e.area==area));
    await saveAi(a);
  }

  static Future<void> renumber(PrintData p)async{
    for(int i=0;i<p.references.length;i++){
      p.references[i]=p.references[i].copyWith(referenceNumber:i+1);
    }
  }
}

/* =========================
   APP
   ========================= */

class App extends StatelessWidget{
  final List<CameraDescription> cameras;
  const App(this.cameras,{super.key});

  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'กล้องสแกนพระ',
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.brown),
    home:HomePage(cameras));
}

/* =========================
   HOME
   ========================= */

class HomePage extends StatefulWidget{
  final List<CameraDescription> cameras;
  const HomePage(this.cameras,{super.key});

  @override State<HomePage> createState()=>_HomePageState();
}

class _HomePageState extends State<HomePage>{
  List<GroupData> groups=[];

  @override
  void initState(){super.initState();load();}

  Future<void> load()async{
    groups=await Storage.load();
    if(mounted)setState((){});
  }

  Future<void> createGroup()async{
    final r=await showDialog<Map<String,String>>(
      context:context,
      builder:(_)=>FormDialog(
        title:'สร้างองค์อ้างอิง',
        fields:const['ชื่อพระ','วัด / สำนัก']));
    if(r==null||r['ชื่อพระ']!.trim().isEmpty)return;

    groups.add(GroupData(
      id:newId(),name:r['ชื่อพระ']!.trim(),
      temple:r['วัด / สำนัก']!.trim(),createdAt:DateTime.now()));
    await Storage.save(groups);
    setState((){});
  }

  Future<void> deleteGroup(GroupData g)async{
    if(!await confirm(context,'ลบองค์อ้างอิง "${g.name}" ?'))return;
    groups.removeWhere((e)=>e.id==g.id);
    await Storage.deleteAiBy(groupId:g.id);
    await Storage.save(groups);
    setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('กล้องสแกนพระ')),
    body:Padding(
      padding:const EdgeInsets.all(16),
      child:Column(children:[
        SizedBox(
          width:double.infinity,
          child:FilledButton.icon(
            onPressed:createGroup,
            icon:const Icon(Icons.add),
            label:const Text('สร้าง / เพิ่มองค์อ้างอิง'))),
        const SizedBox(height:10),
        SizedBox(
          width:double.infinity,
          child:OutlinedButton.icon(
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const AiMemoryTestPage())),
            icon:const Icon(Icons.psychology),
            label:const Text('ทดสอบความจำ AI'))),
        const SizedBox(height:12),
        Expanded(
          child:groups.isEmpty
            ?const Center(child:Text('ยังไม่มีข้อมูลอ้างอิง'))
            :ListView.builder(
              itemCount:groups.length,
              itemBuilder:(_,i){
                final g=groups[i];
                return Card(
                  child:ListTile(
                    title:Text(g.name),
                    subtitle:Text(g.temple.isEmpty
                      ?'ยังไม่ได้ระบุวัด / สำนัก':g.temple),
                    trailing:IconButton(
                      icon:const Icon(Icons.delete_outline),
                      onPressed:()=>deleteGroup(g)),
                    onTap:()=>Navigator.push(context,MaterialPageRoute(
                      builder:(_)=>GroupPage(g,groups,widget.cameras))),
                  ));
              })),
      ])));
}

/* =========================
   AI TEST / CORRECT
   ========================= */

class AiMemoryTestPage extends StatefulWidget{
  const AiMemoryTestPage({super.key});

  @override State<AiMemoryTestPage> createState()=>_AiMemoryTestPageState();
}

class _AiMemoryTestPageState extends State<AiMemoryTestPage>{
  List<AiKnowledge> knowledge=[];
  AiKnowledge? selected;
  AiMemoryTest? test;
  String? question,result,mode,reason;
  final answer=TextEditingController();
  bool randomMode=false;

  @override
  void initState(){super.initState();load();}

  @override
  void dispose(){answer.dispose();super.dispose();}

  Future<void> load()async{
    knowledge=await Storage.loadAi();
    if(mounted)setState((){});
  }

  String makeQuestion(AiKnowledge k)=>
    'AI จำข้อมูล ${k.area} ขององค์อ้างอิงนี้ว่าอย่างไร?';

  void selectKnowledge(AiKnowledge k){
    setState((){
      selected=k;question=makeQuestion(k);randomMode=false;
      answer.clear();test=null;result=null;mode=null;reason=null;
    });
  }

  void randomQuestion(){
    if(knowledge.isEmpty)return;
    final a=[...knowledge]..shuffle();
    selectKnowledge(a.first);
    setState(()=>randomMode=true);
  }

  Future<void> saveAnswer()async{
    if(selected==null||answer.text.trim().isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('กรุณาใส่คำตอบก่อน')));
      return;
    }

    final t=AiMemoryTest(
      id:newId(),knowledgeId:selected!.id,
      referenceId:selected!.referenceId,area:selected!.area,
      question:question!,answer:answer.text.trim(),
      testedAt:DateTime.now());

    await Storage.addTest(t);
    setState((){
      test=t;result=null;mode=null;reason=null;
    });
  }

  String clean(String s)=>s
    .toLowerCase()
    .replaceAll(RegExp(r'[\s\n\r\t.,!?;:(){}\[\]"]'),'')
    .trim();

  Future<void> autoCheck()async{
    if(test==null||selected==null)return;

    final a=clean(test!.answer);
    final ref=clean(selected!.content);
    String r,why;

    if(a.isEmpty){
      r='ไม่มีข้อมูล';why='ไม่ได้ตอบคำถาม';
    }else if(a==ref||a.contains(ref)||ref.contains(a)){
      r='ถูก';why='คำตอบตรงกับข้อมูลอ้างอิง';
    }else{
      final aw=a.split(RegExp(r'[ ,./]+'))
        .where((e)=>e.isNotEmpty).toSet();
      final rw=ref.split(RegExp(r'[ ,./]+'))
        .where((e)=>e.isNotEmpty).toSet();
      final score=rw.isEmpty?0:
        aw.intersection(rw).length/rw.length;

      if(score>=.5){
        r='ใกล้เคียง';why='พบข้อมูลบางส่วนตรงกัน';
      }else{
        r='ผิด';why='ไม่พบข้อมูลตรงกันเพียงพอ';
      }
    }

    await saveResult('ตรวจอัตโนมัติ',r,why);
  }

  Future<void> manualCheck()async{
    if(test==null||selected==null)return;

    final r=await showDialog<String>(
      context:context,
      builder:(_)=>AlertDialog(
        title:const Text('ผู้ใช้ตรวจคำตอบ'),
        content:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('คำตอบ AI:\n${test!.answer}'),
              const SizedBox(height:12),
              Text('ข้อมูลอ้างอิง:\n${selected!.content}'),
            ],
          )),
        actions:[
          for(final x in ['ถูก','ใกล้เคียง','ผิด','ไม่มีข้อมูล'])
            TextButton(
              onPressed:()=>Navigator.pop(context,x),
              child:Text(x)),
        ],
      ));

    if(r!=null)await saveResult(
      'ผู้ใช้ตรวจ',r,'ผู้ใช้เป็นผู้ยืนยันผล');
  }

  Future<void> saveResult(String m,String r,String why)async{
    await Storage.addResult(AiTestResult(
      id:newId(),testId:test!.id,knowledgeId:selected!.id,
      referenceId:selected!.referenceId,area:selected!.area,
      mode:m,result:r,answer:test!.answer,
      referenceAnswer:selected!.content,reason:why,
      checkedAt:DateTime.now()));

    if(!mounted)return;
    setState((){
      mode=m;result=r;reason=why;
    });
  }

  Future<void> correctKnowledge()async{
    if(selected==null)return;

    final c=TextEditingController(text:selected!.content);
    final newText=await showDialog<String>(
      context:context,
      builder:(_)=>AlertDialog(
        title:const Text('แก้ไขความรู้ AI'),
        content:TextField(
          controller:c,maxLines:10,
          decoration:const InputDecoration(
            border:OutlineInputBorder(),
            labelText:'ข้อมูลที่ถูกต้อง',
            hintText:'แก้ไขข้อมูลที่ AI จำผิดหรือยังไม่ครบ')),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(context),
            child:const Text('ยกเลิก')),
          FilledButton(
            onPressed:()=>Navigator.pop(context,c.text.trim()),
            child:const Text('แก้ไขและเรียนรู้ใหม่')),
        ]));
    c.dispose();

    if(newText==null||newText.trim().isEmpty)return;

    await Storage.correctAi(old:selected!,content:newText);
    await load();

    final k=knowledge.firstWhere(
      (e)=>e.id==selected!.id,orElse:()=>selected!);

    setState((){
      selected=k;
      result=null;
      mode=null;
      reason='แก้ไขความรู้แล้ว AI เรียนรู้ข้อมูลใหม่';
      test=null;
      answer.clear();
    });

    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'แก้ไขความรู้แล้ว และบันทึกการเรียนรู้ใหม่เรียบร้อย')));
    }
  }

  Color resultColor(String r){
    if(r=='ถูก')return Colors.green;
    if(r=='ใกล้เคียง')return Colors.orange;
    if(r=='ผิด')return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('ทดสอบความจำ AI')),
    body:knowledge.isEmpty
      ?const Center(
          child:Padding(
            padding:EdgeInsets.all(24),
            child:Text(
              'ยังไม่มีความรู้สำหรับทดสอบ\n\n'
              'ต้องมีข้อมูลที่ AI เรียนรู้ก่อน',
              textAlign:TextAlign.center)))
      :ListView(
        padding:const EdgeInsets.all(16),
        children:[
          const Text(
            'ขั้นที่ 3–6 : ทดสอบ แก้ไข และเรียนรู้ใหม่',
            style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
          const SizedBox(height:8),
          const Text(
            'ระบบนี้ใช้ทดสอบข้อมูลที่บันทึกไว้ก่อน '
            'ยังไม่ใช่การตรวจภาพด้วยโมเดล AI จริง'),
          const SizedBox(height:16),
          Row(children:[
            Expanded(
              child:FilledButton.icon(
                onPressed:randomQuestion,
                icon:const Icon(Icons.shuffle),
                label:const Text('สุ่มคำถาม'))),
            const SizedBox(width:10),
            Expanded(
              child:OutlinedButton.icon(
                onPressed:()async{
                  final k=await showDialog<AiKnowledge>(
                    context:context,
                    builder:(_)=>KnowledgeSelectDialog(data:knowledge));
                  if(k!=null)selectKnowledge(k);
                },
                icon:const Icon(Icons.list),
                label:const Text('เลือกคำถาม'))),
          ]),
          if(selected!=null)...[
            const SizedBox(height:20),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(16),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(randomMode?'🎲 คำถามสุ่ม':'📋 คำถาม',
                      style:const TextStyle(fontWeight:FontWeight.bold)),
                    const SizedBox(height:8),
                    Text('ด้าน: ${selected!.area}'),
                    const SizedBox(height:8),
                    Text(question!,
                      style:const TextStyle(
                        fontSize:18,fontWeight:FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height:12),
            TextField(
              controller:answer,maxLines:6,
              decoration:const InputDecoration(
                labelText:'คำตอบ AI',
                hintText:'ใส่สิ่งที่ AI จำได้จากความรู้เดิม',
                border:OutlineInputBorder())),
            const SizedBox(height:12),
            if(test==null)
              SizedBox(
                width:double.infinity,
                child:FilledButton.icon(
                  onPressed:saveAnswer,
                  icon:const Icon(Icons.save),
                  label:const Text('บันทึกคำตอบ'))),
            if(test!=null)...[
              const SizedBox(height:8),
              const Text(
                'ขั้นที่ 4 : ตรวจสอบคำตอบ',
                style:TextStyle(
                  fontSize:18,fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              Row(children:[
                Expanded(
                  child:FilledButton.icon(
                    onPressed:manualCheck,
                    icon:const Icon(Icons.person),
                    label:const Text('ผู้ใช้ตรวจ'))),
                const SizedBox(width:10),
                Expanded(
                  child:OutlinedButton.icon(
                    onPressed:autoCheck,
                    icon:const Icon(Icons.psychology),
                    label:const Text('ตรวจอัตโนมัติ'))),
              ]),
              const SizedBox(height:12),
              if(result!=null)
                Card(
                  child:Padding(
                    padding:const EdgeInsets.all(16),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        Text('ผลตรวจ: $result',
                          style:TextStyle(
                            fontSize:20,fontWeight:FontWeight.bold,
                            color:resultColor(result!))),
                        if(mode!=null)Text('วิธีตรวจ: $mode'),
                        const SizedBox(height:8),
                        Text('คำตอบ AI:\n${test!.answer}'),
                        const SizedBox(height:8),
                        Text('ข้อมูลอ้างอิง:\n${selected!.content}'),
                        if(reason!=null)...[
                          const SizedBox(height:8),
                          Text('เหตุผล: $reason')],
                        if(result=='ผิด'||result=='ใกล้เคียง')...[
                          const SizedBox(height:14),
                          SizedBox(
                            width:double.infinity,
                            child:FilledButton.icon(
                              onPressed:correctKnowledge,
                              icon:const Icon(Icons.edit),
                              label:const Text('แก้ไขความรู้และให้ AI เรียนรู้ใหม่'))),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ));
}

/* =========================
   KNOWLEDGE SELECT
   ========================= */

class KnowledgeSelectDialog extends StatelessWidget{
  final List<AiKnowledge> data;
  const KnowledgeSelectDialog({required this.data,super.key});

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('เลือกความรู้ที่จะทดสอบ'),
    content:SizedBox(
      width:double.maxFinite,height:400,
      child:ListView.builder(
        itemCount:data.length,
        itemBuilder:(_,i){
          final k=data[i];
          return Card(
            child:ListTile(
              leading:const Icon(Icons.psychology),
              title:Text(k.area),
              subtitle:Text(
                'องค์อ้างอิง ID: ${k.referenceId}',
                maxLines:1,overflow:TextOverflow.ellipsis),
              onTap:()=>Navigator.pop(context,k)));
        })),
    actions:[
      TextButton(
        onPressed:()=>Navigator.pop(context),
        child:const Text('ยกเลิก'))]);
}

/* =========================
   GROUP
   ========================= */

class GroupPage extends StatefulWidget{
  final GroupData group;
  final List<GroupData> groups;
  final List<CameraDescription> cameras;

  const GroupPage(this.group,this.groups,this.cameras,{super.key});

  @override State<GroupPage> createState()=>_GroupPageState();
}

class _GroupPageState extends State<GroupPage>{
  Future<void> save()=>Storage.save(widget.groups);

  Future<void> addModel()async{
    final n=await textDialog(context,'ชื่อรุ่น');
    if(n==null||n.trim().isEmpty)return;
    widget.group.models.add(ModelData(
      id:newId(),name:n.trim(),createdAt:DateTime.now()));
    widget.group.updatedAt=DateTime.now();
    await save();setState((){});
  }

  Future<void> deleteModel(ModelData m)async{
    if(!await confirm(context,'ลบรุ่น "${m.name}" ?'))return;
    widget.group.models.removeWhere((e)=>e.id==m.id);
    await Storage.deleteAiBy(modelId:m.id);
    await save();setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.group.name)),
    floatingActionButton:FloatingActionButton(
      onPressed:addModel,child:const Icon(Icons.add)),
    body:widget.group.models.isEmpty
      ?const Center(child:Text('ยังไม่มีรุ่น'))
      :ListView.builder(
        padding:const EdgeInsets.all(12),
        itemCount:widget.group.models.length,
        itemBuilder:(_,i){
          final m=widget.group.models[i];
          return Card(
            child:ListTile(
              title:Text(m.name),
              subtitle:Text('${m.types.length} ประเภท'),
              trailing:IconButton(
                icon:const Icon(Icons.delete_outline),
                onPressed:()=>deleteModel(m)),
              onTap:()async{
                await Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>ModelPage(
                    widget.group,m,widget.groups,widget.cameras)));
                setState((){});
              }));
        }));
}

/* =========================
   MODEL
   ========================= */

class ModelPage extends StatefulWidget{
  final GroupData group;
  final ModelData model;
  final List<GroupData> groups;
  final List<CameraDescription> cameras;

  const ModelPage(
    this.group,this.model,this.groups,this.cameras,{super.key});

  @override State<ModelPage> createState()=>_ModelPageState();
}

class _ModelPageState extends State<ModelPage>{
  Future<void> save()=>Storage.save(widget.groups);

  Future<void> addType()async{
    final t=await showDialog<String>(
      context:context,builder:(_)=>const TypeDialog());
    if(t==null||t.trim().isEmpty)return;
    widget.model.types.add(TypeData(
      id:newId(),name:t.trim(),createdAt:DateTime.now()));
    await save();setState((){});
  }

  Future<void> deleteType(TypeData t)async{
    if(!await confirm(context,'ลบประเภท "${t.name}" ?'))return;
    widget.model.types.removeWhere((e)=>e.id==t.id);
    await Storage.deleteAiBy(typeId:t.id);
    await save();setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.model.name)),
    floatingActionButton:FloatingActionButton(
      onPressed:addType,child:const Icon(Icons.add)),
    body:widget.model.types.isEmpty
      ?const Center(child:Text('ยังไม่มีประเภท'))
      :ListView.builder(
        padding:const EdgeInsets.all(12),
        itemCount:widget.model.types.length,
        itemBuilder:(_,i){
          final t=widget.model.types[i];
          return Card(
            child:ListTile(
              title:Text(t.name),
              subtitle:Text('${t.prints.length} พิมพ์'),
              trailing:IconButton(
                icon:const Icon(Icons.delete_outline),
                onPressed:()=>deleteType(t)),
              onTap:()async{
                await Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>TypePage(
                    widget.group,widget.model,t,
                    widget.groups,widget.cameras)));
                setState((){});
              }));
        }));
}

/* =========================
   TYPE
   ========================= */

class TypePage extends StatefulWidget{
  final GroupData group;
  final ModelData model;
  final TypeData type;
  final List<GroupData> groups;
  final List<CameraDescription> cameras;

  const TypePage(
    this.group,this.model,this.type,this.groups,this.cameras,{super.key});

  @override State<TypePage> createState()=>_TypePageState();
}

class _TypePageState extends State<TypePage>{
  Future<void> save()=>Storage.save(widget.groups);

  Future<void> addPrint()async{
    final n=await textDialog(
      context,'ชื่อพิมพ์',hint:'เว้นว่างได้');
    if(n==null)return;

    widget.type.prints.add(PrintData(
      id:newId(),
      name:n.trim().isEmpty?'พิมพ์เดียว':n.trim(),
      createdAt:DateTime.now()));
    await save();setState((){});
  }

  Future<void> deletePrint(PrintData p)async{
    if(!await confirm(context,'ลบพิมพ์ "${p.name}" ?'))return;
    widget.type.prints.removeWhere((e)=>e.id==p.id);
    await Storage.deleteAiBy(printId:p.id);
    await save();setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.type.name)),
    floatingActionButton:FloatingActionButton(
      onPressed:addPrint,child:const Icon(Icons.add)),
    body:widget.type.prints.isEmpty
      ?const Center(child:Text('ยังไม่มีพิมพ์'))
      :ListView.builder(
        padding:const EdgeInsets.all(12),
        itemCount:widget.type.prints.length,
        itemBuilder:(_,i){
          final p=widget.type.prints[i];
          return Card(
            child:ListTile(
              title:Text(p.name),
              subtitle:Text('มีองค์อ้างอิง ${p.references.length} องค์'),
              trailing:IconButton(
                icon:const Icon(Icons.delete_outline),
                onPressed:()=>deletePrint(p)),
              onTap:()async{
                await Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>PrintPage(
                    widget.group,widget.model,widget.type,p,
                    widget.groups,widget.cameras)));
                setState((){});
              }));
        }));
}

/* =========================
   PRINT
   ========================= */

class PrintPage extends StatefulWidget{
  final GroupData group;
  final ModelData model;
  final TypeData type;
  final PrintData print;
  final List<GroupData> groups;
  final List<CameraDescription> cameras;

  const PrintPage(
    this.group,this.model,this.type,this.print,
    this.groups,this.cameras,{super.key});

  @override State<PrintPage> createState()=>_PrintPageState();
}

class _PrintPageState extends State<PrintPage>{
  Future<void> save()=>Storage.save(widget.groups);

  Future<void> addReference()async{
    final r=ReferenceData(
      id:newId(),
      referenceNumber:widget.print.references.length+1,
      createdAt:DateTime.now());

    widget.print.references.add(r);
    await save();
    if(!mounted)return;

    await Navigator.push(context,MaterialPageRoute(
      builder:(_)=>ReferencePage(
        widget.group,widget.model,widget.type,widget.print,r,
        widget.groups,widget.cameras)));

    await Storage.renumber(widget.print);
    await save();setState((){});
  }

  Future<void> deleteReference(ReferenceData r)async{
    if(!await confirm(
      context,'ลบองค์อ้างอิงที่ ${r.referenceNumber} ?'))return;

    widget.print.references.removeWhere((e)=>e.id==r.id);
    await Storage.deleteAiBy(referenceId:r.id);
    await Storage.renumber(widget.print);
    await save();setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.print.name)),
    floatingActionButton:FloatingActionButton(
      onPressed:addReference,child:const Icon(Icons.add)),
    body:widget.print.references.isEmpty
      ?const Center(child:Text('ยังไม่มีองค์อ้างอิง'))
      :ListView.builder(
        padding:const EdgeInsets.all(12),
        itemCount:widget.print.references.length,
        itemBuilder:(_,i){
          final r=widget.print.references[i];
          return Card(
            child:ListTile(
              title:Text('องค์อ้างอิงที่ ${r.referenceNumber}'),
              subtitle:Text('มีข้อมูล ${r.scans.length}/4 ด้าน'),
              trailing:IconButton(
                icon:const Icon(Icons.delete_outline),
                onPressed:()=>deleteReference(r)),
              onTap:()async{
                await Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>ReferencePage(
                    widget.group,widget.model,widget.type,widget.print,r,
                    widget.groups,widget.cameras)));
                await save();setState((){});
              }));
        }));
}

/* =========================
   REFERENCE
   ========================= */

class ReferencePage extends StatefulWidget{
  final GroupData group;
  final ModelData model;
  final TypeData type;
  final PrintData print;
  final ReferenceData reference;
  final List<GroupData> groups;
  final List<CameraDescription> cameras;

  const ReferencePage(
    this.group,this.model,this.type,this.print,this.reference,
    this.groups,this.cameras,{super.key});

  @override State<ReferencePage> createState()=>_ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage>{
  Future<void> save()=>Storage.save(widget.groups);

  ScanResult? getScan(String area){
    for(final s in widget.reference.scans){
      if(s.area==area)return s;
    }
    return null;
  }

  Future<void> scan(String area)async{
    final r=await Navigator.push<ScanResult>(
      context,MaterialPageRoute(
        builder:(_)=>ScanPage(area:area,cameras:widget.cameras)));

    if(r==null)return;

    widget.reference.scans.removeWhere((e)=>e.area==area);
    widget.reference.scans.add(r);
    widget.reference.updatedAt=DateTime.now();

    await Storage.deleteAiBy(
      referenceId:widget.reference.id,area:area);

    await Storage.addAi(
      group:widget.group,model:widget.model,type:widget.type,
      print:widget.print,reference:widget.reference,scan:r);

    await save();setState((){});
  }

  Future<void> deleteScan(String area)async{
    if(!await confirm(context,'ลบข้อมูลด้าน$area ?'))return;

    widget.reference.scans.removeWhere((e)=>e.area==area);
    await Storage.deleteAiBy(
      referenceId:widget.reference.id,area:area);
    await save();setState((){});
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:Text('องค์อ้างอิงที่ ${widget.reference.referenceNumber}')),
    body:ListView(
      padding:const EdgeInsets.all(12),
      children:[
        for(final area in areas)
          Card(
            child:ListTile(
              title:Text(area),
              subtitle:Text(
                getScan(area)==null
                  ?'ยังไม่ได้ระบุข้อมูล'
                  :'มีข้อมูล\n${getScan(area)!.details}'),
              isThreeLine:true,
              trailing:getScan(area)==null
                ?const Icon(Icons.camera_alt_outlined)
                :IconButton(
                  icon:const Icon(Icons.delete_outline),
                  onPressed:()=>deleteScan(area)),
              onTap:()=>scan(area))),
        const SizedBox(height:12),
        const Text(
          'AI จะเรียนรู้จากข้อมูลขององค์อ้างอิงแต่ละองค์\n\n'
          '1 ฐานความรู้\n'
          '2 ประวัติการเรียนรู้\n'
          '3 ทดสอบความจำ\n'
          '4 ตรวจคำตอบ\n'
          '5 แก้ไขความรู้\n'
          '6 เรียนรู้ใหม่\n\n'
          'ระบบไม่เก็บรูปภาพถาวร',
          textAlign:TextAlign.center),
      ],
    ));
}

/* =========================
   SCAN
   ========================= */

class ScanPage extends StatelessWidget{
  final String area;
  final List<CameraDescription> cameras;

  const ScanPage({required this.area,required this.cameras,super.key});

  Future<void> scanCamera(BuildContext context)async{
    if(cameras.isEmpty)return;

    final back=cameras.where(
      (c)=>c.lensDirection==CameraLensDirection.back);
    final camera=back.isNotEmpty?back.first:cameras.first;

    final file=await Navigator.push<XFile>(
      context,MaterialPageRoute(
        builder:(_)=>CameraScanPage(camera)));

    if(file==null)return;

    try{await File(file.path).delete();}catch(_){}

    if(!context.mounted)return;
    await enterKnowledge(context);
  }

  Future<void> scanGallery(BuildContext context)async{
    final file=await ImagePicker().pickImage(
      source:ImageSource.gallery);

    if(file==null||!context.mounted)return;

    await enterKnowledge(context);
  }

  Future<void> enterKnowledge(BuildContext context)async{
    final c=TextEditingController();

    final text=await showDialog<String>(
      context:context,
      builder:(_)=>AlertDialog(
        title:Text('ข้อมูลที่ต้องการให้ AI เรียนรู้$area'),
        content:TextField(
          controller:c,maxLines:10,
          decoration:const InputDecoration(
            border:OutlineInputBorder(),
            labelText:'รายละเอียด',
            hintText:
              'บันทึกลักษณะที่มองเห็นหรือข้อมูลอ้างอิง '
              'เช่น เนื้อหา รูปทรง จุดสังเกต ตำหนิ พิมพ์ ฯลฯ')),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(context),
            child:const Text('ยกเลิก')),
          FilledButton(
            onPressed:()=>Navigator.pop(context,c.text.trim()),
            child:const Text('บันทึกการเรียนรู้')),
        ]));

    c.dispose();

    if(text==null||text.trim().isEmpty)return;

    Navigator.pop(context,ScanResult(
      area:area,details:text.trim()));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text('สแกน$area')),
    body:Padding(
      padding:const EdgeInsets.all(20),
      child:Column(
        mainAxisAlignment:MainAxisAlignment.center,
        children:[
          const Text(
            'ภาพใช้ชั่วคราวเท่านั้น\n'
            'หลังจากนั้นระบบจะเก็บเฉพาะข้อมูลการเรียนรู้',
            textAlign:TextAlign.center),
          const SizedBox(height:20),
          SizedBox(
            width:double.infinity,
            child:FilledButton.icon(
              onPressed:()=>scanCamera(context),
              icon:const Icon(Icons.camera_alt),
              label:const Text('เปิดกล้อง'))),
          const SizedBox(height:12),
          SizedBox(
            width:double.infinity,
            child:OutlinedButton.icon(
              onPressed:()=>scanGallery(context),
              icon:const Icon(Icons.photo_library_outlined),
              label:const Text('เลือกจากแกลเลอรี'))),
        ],
      )));
}

/* =========================
   CAMERA
   ========================= */

class CameraScanPage extends StatefulWidget{
  final CameraDescription camera;
  const CameraScanPage(this.camera,{super.key});

  @override State<CameraScanPage> createState()=>_CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>{
  late CameraController controller;
  Future<void>? initialize;

  @override
  void initState(){
    super.initState();
    controller=CameraController(
      widget.camera,ResolutionPreset.medium,enableAudio:false);
    initialize=controller.initialize();
  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  Future<void> capture()async{
    if(!controller.value.isInitialized||
       controller.value.isTakingPicture)return;

    final file=await controller.takePicture();
    if(!mounted)return;
    Navigator.pop(context,file);
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('กล้อง')),
    body:FutureBuilder(
      future:initialize,
      builder:(_,s){
        if(s.connectionState!=ConnectionState.done){
          return const Center(child:CircularProgressIndicator());
        }

        return Stack(
          fit:StackFit.expand,
          children:[
            CameraPreview(controller),
            Positioned(
              bottom:30,left:0,right:0,
              child:Center(
                child:FloatingActionButton.large(
                  onPressed:capture,
                  child:const Icon(Icons.camera))),
            ),
          ]);
      }));
}

/* =========================
   FORM
   ========================= */

class FormDialog extends StatefulWidget{
  final String title;
  final List<String> fields;

  const FormDialog({
    required this.title,required this.fields,super.key});

  @override State<FormDialog> createState()=>_FormDialogState();
}

class _FormDialogState extends State<FormDialog>{
  late final Map<String,TextEditingController> c;

  @override
  void initState(){
    super.initState();
    c={for(final f in widget.fields)f:TextEditingController()};
  }

  @override
  void dispose(){
    for(final x in c.values)x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:Text(widget.title),
    content:SingleChildScrollView(
      child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          for(final f in widget.fields)
            Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:TextField(
                controller:c[f],
                decoration:InputDecoration(
                  labelText:f,
                  border:const OutlineInputBorder())),
            ),
        ],
      )),
    actions:[
      TextButton(
        onPressed:()=>Navigator.pop(context),
        child:const Text('ยกเลิก')),
      FilledButton(
        onPressed:()=>Navigator.pop(
          context,{for(final f in widget.fields)f:c[f]!.text}),
        child:const Text('บันทึก')),
    ]);
}

/* =========================
   TYPE
   ========================= */

class TypeDialog extends StatefulWidget{
  const TypeDialog({super.key});

  @override State<TypeDialog> createState()=>_TypeDialogState();
}

class _TypeDialogState extends State<TypeDialog>{
  String? selected;
  final other=TextEditingController();

  @override
  void dispose(){other.dispose();super.dispose();}

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('เลือกประเภท'),
    content:Column(
      mainAxisSize:MainAxisSize.min,
      children:[
        DropdownButtonFormField<String>(
          value:selected,isExpanded:true,
          items:typeOptions.map(
            (e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
          onChanged:(v)=>setState(()=>selected=v),
          decoration:const InputDecoration(
            border:OutlineInputBorder(),labelText:'ประเภท')),
        if(selected=='อื่น ๆ')...[
          const SizedBox(height:10),
          TextField(
            controller:other,
            decoration:const InputDecoration(
              border:OutlineInputBorder(),labelText:'ระบุประเภท')),
        ],
      ],
    ),
    actions:[
      TextButton(
        onPressed:()=>Navigator.pop(context),
        child:const Text('ยกเลิก')),
      FilledButton(
        onPressed:(){
          if(selected==null)return;

          if(selected=='อื่น ๆ'){
            if(other.text.trim().isEmpty)return;
            Navigator.pop(context,other.text.trim());
          }else{
            Navigator.pop(context,selected);
          }
        },
        child:const Text('บันทึก')),
    ]);
}

/* =========================
   TEXT DIALOG
   ========================= */

Future<String?> textDialog(
  BuildContext context,String title,{String? hint})async{
  final c=TextEditingController();

  final r=await showDialog<String>(
    context:context,
    builder:(_)=>AlertDialog(
      title:Text(title),
      content:TextField(
        controller:c,autofocus:true,
        decoration:InputDecoration(
          border:const OutlineInputBorder(),hintText:hint)),
      actions:[
        TextButton(
          onPressed:()=>Navigator.pop(context),
          child:const Text('ยกเลิก')),
        FilledButton(
          onPressed:()=>Navigator.pop(context,c.text),
          child:const Text('บันทึก')),
      ]));

  c.dispose();
  return r;
}

/* =========================
   CONFIRM
   ========================= */

Future<bool> confirm(
  BuildContext context,String message)async{
  final r=await showDialog<bool>(
    context:context,
    builder:(_)=>AlertDialog(
      content:Text(message),
      actions:[
        TextButton(
          onPressed:()=>Navigator.pop(context,false),
          child:const Text('ยกเลิก')),
        FilledButton(
          onPressed:()=>Navigator.pop(context,true),
          child:const Text('ลบ')),
      ]));

  return r==true;
}
