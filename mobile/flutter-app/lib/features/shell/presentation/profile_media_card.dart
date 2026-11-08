import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';

class ProfileMediaCard extends StatefulWidget {
  const ProfileMediaCard({super.key, required this.api, required this.profile,
    required this.onChanged, required this.onBusy, this.enabled=true, this.selectPhoto});
  final MyAapthaApi api;
  final UserProfileModel profile;
  final ValueChanged<UserProfileModel> onChanged;
  final ValueChanged<bool> onBusy;
  final bool enabled;
  final Future<PlatformFile?> Function()? selectPhoto;
  @override State<ProfileMediaCard> createState()=>_ProfileMediaCardState();
}

class _ProfileMediaCardState extends State<ProfileMediaCard> {
  bool busy=false;
  String? failure;
  List<String> get photos=>(widget.profile.data['photos'] as List? ?? []).cast<String>();
  bool get enabled=>widget.enabled&&!busy;
  Future<void> perform(Future<UserProfileModel?> Function() operation) async {
    if(!enabled)return;
    setState((){busy=true;failure=null;});widget.onBusy(true);
    try {final updated=await operation();if(mounted&&updated!=null)widget.onChanged(updated);}
    catch(e){if(mounted)setState(()=>failure=e.toString());}
    finally {if(mounted){setState(()=>busy=false);widget.onBusy(false);}}
  }
  Future<void> pick(bool gallery) => perform(() async {
    final PlatformFile? file;
    if(widget.selectPhoto!=null){file=await widget.selectPhoto!();}
    else {
      final selection=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png','webp'],withData:true,allowMultiple:false);
      file=selection?.files.single;
    }
    if(file==null)return null;
    final Uint8List? bytes=file.bytes;
    if(bytes==null)throw const FormatException('The photo could not be read. Please select it again.');
    MyAapthaApi.validateProfilePhoto(bytes,file.name);
    return widget.api.uploadProfilePhoto(bytes,file.name,gallery:gallery);
  });
  Future<void> remove({int? index}) async {
    if(!enabled)return;
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:Text(index==null?'Remove profile photo?':'Remove gallery photo?'),
      content:const Text('This removes the stored photo from your profile.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Remove photo'))]));
    if(confirmed==true&&mounted)await perform(()=>widget.api.removeProfilePhoto(galleryIndex:index));
  }
  Widget image(String url,{double size=80})=>ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(widget.api.profilePhotoUrl(url),width:size,height:size,fit:BoxFit.cover,errorBuilder:(_,error,stack)=>SizedBox(width:size,height:size,child:const Icon(Icons.person_outline,size:36))));
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text('Profile photos',style:Theme.of(context).textTheme.titleMedium)),const InfoHelp(title:'Profile photos',message:'JPG, PNG or WebP, up to 5 MB per photo and eight gallery photos. Your storage quota applies. Photos stay until you delete them. Profile photos use publicly accessible media links.')]),
    const SizedBox(height:14),
    if(widget.profile.value('profilePhoto').isNotEmpty) image(widget.profile.value('profilePhoto')),
    Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:enabled?()=>pick(false):null,icon:const Icon(Icons.add_a_photo_outlined),label:Text(widget.profile.value('profilePhoto').isEmpty?'Upload photo':'Change photo')),
      if(widget.profile.value('profilePhoto').isNotEmpty)TextButton(onPressed:enabled?()=>remove():null,child:const Text('Remove profile photo'))]),
    const SizedBox(height:12),Text('Gallery (${photos.length}/8)',style:Theme.of(context).textTheme.titleSmall),
    if(photos.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Wrap(spacing:12,runSpacing:12,children:[for(var i=0;i<photos.length;i++)Column(mainAxisSize:MainAxisSize.min,children:[image(photos[i]),IconButton(tooltip:'Remove gallery photo ${i+1}',onPressed:enabled?()=>remove(index:i):null,icon:const Icon(Icons.delete_outline))])])),
    TextButton.icon(onPressed:enabled&&photos.length<8?()=>pick(true):null,icon:const Icon(Icons.collections_outlined),label:const Text('Add gallery photo')),
    if(busy)const LinearProgressIndicator(semanticsLabel:'Updating profile photos'),
    if(failure!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(failure!,semanticsLabel:'Photo update failed: $failure',style:TextStyle(color:Theme.of(context).colorScheme.error))),
  ])));
}
