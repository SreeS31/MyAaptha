import {test,expect} from '@playwright/test';
import {validateUploadMetadata,validateUpload,attachmentAccept} from '../app/lib/upload-security';
test('attachment selection includes documents and media and rejects dangerous names',()=>{
 for(const extension of ['pdf','docx','txt','jpg','mp3','mp4']){expect(attachmentAccept).toContain(`.${extension}`);expect(()=>validateUploadMetadata({name:`safe.${extension}`,size:100})).not.toThrow();}
 for(const name of ['payload.exe','photo.exe.jpg','macro.docm','page.svg','payload:notes.txt'])expect(()=>validateUploadMetadata({name,size:100})).toThrow();
 expect(()=>validateUploadMetadata({name:'empty.txt',size:0})).toThrow();
});
test('client content checks reject disguised executables and mismatched files',async()=>{
 await expect(validateUpload(new File(['MZ executable'], 'fake.jpg'))).rejects.toThrow('Unsafe');
 await expect(validateUpload(new File(['plain text'], 'fake.pdf'))).rejects.toThrow('contents');
 await expect(validateUpload(new File(['%PDF-1.7 safe'], 'report.pdf'))).resolves.toBeUndefined();
});
