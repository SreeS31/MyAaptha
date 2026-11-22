import * as api from './meeting-api';
import {ApiError,fetchCallIceConfiguration} from './api';

/** A session owns every device and peer; release is safe during any awaited operation. */
export class MeetingSession {
  private stopped=false;private timer:ReturnType<typeof setTimeout>|undefined;private after=0;
  private peers=new Map<number,RTCPeerConnection>();private pending=new Map<number,RTCIceCandidateInit[]>();
  private streams=new Map<number,MediaStream>();private configuration:RTCConfiguration={};
  private screen:MediaStream|null=null;
  constructor(public room:api.CallRoom,public local:MediaStream,private changed:(room:api.CallRoom,streams:Map<number,MediaStream>)=>void,private failed:(message:string)=>void,private ended:()=>void,private ice?:RTCConfiguration){}
  async start(){
    try{const configuration=this.ice||{iceServers:(await fetchCallIceConfiguration()).iceServers};if(this.stopped)return;this.configuration=configuration;this.room=await api.joinCall(this.room.id);if(!this.stopped)await this.tick();}
    catch(error){if(!this.stopped)this.failed(error instanceof Error?error.message:'Unable to join call');this.release();this.ended();void api.leaveCall(this.room.id).catch(()=>{});}
  }
  private connection(id:number){
    const existing=this.peers.get(id);if(existing)return existing;
    const peer=new RTCPeerConnection(this.configuration);this.peers.set(id,peer);
    this.local.getTracks().forEach(track=>peer.addTrack(track.kind==='video'&&this.screen?this.screen.getVideoTracks()[0]:track,this.local));
    peer.onicecandidate=event=>{if(event.candidate&&!this.stopped)void api.sendCallSignal(this.room.id,id,'ice',event.candidate.toJSON()).catch(()=>{if(!this.stopped)this.failed('Call connection was interrupted.');});};
    peer.ontrack=event=>{if(this.stopped)return;const stream=this.streams.get(id)||new MediaStream();if(!stream.getTracks().some(track=>track.id===event.track.id))stream.addTrack(event.track);this.streams.set(id,stream);this.changed(this.room,new Map(this.streams));};
    peer.onconnectionstatechange=()=>{if(!this.stopped&&peer.connectionState==='failed')this.failed('A participant could not connect. Try rejoining the call.');};
    return peer;
  }
  private async tick(){
    if(this.stopped)return;
    try{
      const room=await api.getCall(this.room.id);if(this.stopped)return;
      this.room=room;if(room.ended){this.release();this.ended();return;}
      const participants=room.members.filter(member=>member.status==='JOINED'&&member.userId!==room.currentUserId);
      for(const [id,peer] of Array.from(this.peers)){if(!participants.some(member=>member.userId===id)){peer.close();this.peers.delete(id);this.streams.delete(id);this.pending.delete(id);}}
      for(const member of participants){
        if(this.peers.has(member.userId))continue;
        const peer=this.connection(member.userId);
        if(room.currentUserId<member.userId){await peer.setLocalDescription(await peer.createOffer());if(this.stopped)return;await api.sendCallSignal(room.id,member.userId,'offer',peer.localDescription?.toJSON());}
      }
      for(const signal of await api.callSignals(room.id,this.after)){
        if(this.stopped)return;
        if(!participants.some(member=>member.userId===signal.senderId)){this.after=signal.id;continue;}
        const peer=this.connection(signal.senderId),payload=JSON.parse(signal.payload);
        if(signal.type==='ice'){
          if(peer.remoteDescription)await peer.addIceCandidate(payload);else this.pending.set(signal.senderId,[...(this.pending.get(signal.senderId)||[]),payload]);
        }else{
          await peer.setRemoteDescription(payload);
          for(const candidate of this.pending.get(signal.senderId)||[])await peer.addIceCandidate(candidate);
          this.pending.delete(signal.senderId);
          if(signal.type==='offer'){await peer.setLocalDescription(await peer.createAnswer());await api.sendCallSignal(room.id,signal.senderId,'answer',peer.localDescription?.toJSON());}
        }
        this.after=signal.id;
      }
      if(!this.stopped)this.changed(room,new Map(this.streams));
    }catch(error){if(!this.stopped){this.failed(error instanceof Error?error.message:'Unable to check call status');if(error instanceof ApiError&&[401,403,404,409].includes(error.status)){this.release();this.ended();return;}}}
    if(!this.stopped)this.timer=setTimeout(()=>void this.tick(),1500);
  }
  async shareScreen(stream:MediaStream){
    if(this.stopped){stream.getTracks().forEach(track=>track.stop());return;}
    const video=stream.getVideoTracks()[0];
    if(!video)throw new Error('No screen was selected');
    const restore=()=>{if(this.screen===stream)this.screen=null;const camera=this.local.getVideoTracks()[0];if(!this.stopped)for(const peer of Array.from(this.peers.values())){const sender=peer.getSenders().find(value=>value.track?.kind==='video');if(sender)void sender.replaceTrack(camera||null).catch(()=>{});}stream.getTracks().forEach(track=>track.stop());};
    this.screen=stream;
    try{for(const peer of Array.from(this.peers.values())){const sender=peer.getSenders().find(value=>value.track?.kind==='video');if(sender)await sender.replaceTrack(video);}if(this.stopped){restore();return;}return restore;}
    catch(error){restore();throw error;}
  }
  release(){this.stopped=true;if(this.timer)clearTimeout(this.timer);this.screen?.getTracks().forEach(track=>track.stop());this.screen=null;for(const peer of Array.from(this.peers.values())){peer.ontrack=null;peer.onicecandidate=null;peer.onconnectionstatechange=null;peer.close();}this.peers.clear();this.local.getTracks().forEach(track=>track.stop());for(const stream of Array.from(this.streams.values()))stream.getTracks().forEach(track=>track.stop());this.streams.clear();}
}
