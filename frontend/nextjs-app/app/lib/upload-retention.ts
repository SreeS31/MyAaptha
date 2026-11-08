import type {UploadLevel} from './api';
// Retained for older callers; ordinary attachments have no automatic expiry.
export async function chooseUploadRetention(_level:UploadLevel):Promise<number>{return 0;}
