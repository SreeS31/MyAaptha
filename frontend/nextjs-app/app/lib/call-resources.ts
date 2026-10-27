/** Own media independently of React render timing; generations reject late work. */
export class CallResources {
 private generation=0;
 private local:MediaStream|null=null;
 private remote:MediaStream|null=null;
 private peer:RTCPeerConnection|null=null;
 get connection(){return this.peer;}
 get token(){return this.generation;}
 isCurrent(token:number){return token===this.generation;}
 begin(){this.release();return this.generation;}
 private stop(stream:MediaStream|null){for(const track of stream?.getTracks()||[]){try{track.stop();}catch{/* Continue releasing other devices. */}}}
 attachLocal(token:number,stream:MediaStream){if(!this.isCurrent(token)){this.stop(stream);return false;}this.local=stream;return true;}
 attachRemote(token:number,stream:MediaStream){if(!this.isCurrent(token)){this.stop(stream);return false;}if(this.remote&&this.remote!==stream)this.stop(this.remote);this.remote=stream;return true;}
 attachConnection(token:number,connection:RTCPeerConnection){if(!this.isCurrent(token)){connection.close();return false;}this.peer=connection;return true;}
 release(){
  this.generation++;
  const peer=this.peer,local=this.local,remote=this.remote;
  this.peer=null;this.local=null;this.remote=null;
  if(peer){peer.ontrack=null;peer.onconnectionstatechange=null;try{peer.close();}catch{/* Device release must still run. */}}
  this.stop(local);if(remote!==local)this.stop(remote);
 }
}
