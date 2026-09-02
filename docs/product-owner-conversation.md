# Product Owner Conversation Record

This is the durable, append-only record of product requirements communicated by the MyAaptha product owner in the development conversation. It preserves wording where practical and records image-only context as a note. Add future requirements chronologically; do not silently rewrite earlier entries.

## 2026-08 to 2026-09

1. Find `CircleNet-AI` anywhere in the entire application and replace it with `MyAaptha`, including GitHub.
2. Allow users to upload a complete diagnostic report. AI must read all parameters without manual entry, record the report date, chart values over time, identify out-of-range values, and provide careful suggestions. Examples included lipid profiles and CBP reports with ten or more parameters.
3. Push the project to `https://github.com/SreeS31/MyAaptha`.
4. Attachments must open in an in-app viewer or player on first click instead of downloading immediately. Audio and video should play in place; documents should open in view mode. A right-click or overflow menu should provide WhatsApp-like actions including download.
5. The frontend repeatedly remained on loading states. Investigate and fix server/session handling rather than leaving pages indefinitely pending.
6. Remove the sidebar phrase `Private by design`. Provide a clearly discoverable sign-out control and make sign-out complete immediately instead of remaining pending.
7. Resolve `Request failed: 403` on health records.
8. Allow useful document, audio, video, PDF, spreadsheet, and related file formats, including MP3. Do not restrict the file picker to an incomplete format list.
9. The top search bar is global search. It must search people, relationships, circles, private chats, circle messages, content, and attachment names wherever the current user is authorized to see them. A search control inside a page is scoped only to that page.
10. Resolve global-search internal server errors and server availability/sign-in failures.
11. Use a permanent local PostgreSQL or MySQL database that can later move to a cloud managed database. Do not use temporary or in-memory storage for application data.
12. Apply client-side and server-side validation to every field, form, page, search input, mobile flow, web flow, and API. Server-side validation is authoritative and must occur before an action is executed.
13. Treat upload security as a high priority. Reject scripts, malware, executable files, disguised formats, and unnecessary files before storing or processing them. Validate on both client and server, with the server authoritative.
14. Build an enterprise-level user experience suitable for millions of users, with attractive light colors, professional typography, and efficient workflows.
15. Keep web and mobile navigation, labels, menus, visual language, and behavior consistent so users do not have to relearn the application.
16. Design MyAaptha for the next ten years: social communication with relatives, friends, and followers; goals and life settlements; document management; health and wealth guidance; and extensive AI assistance that reduces routine human work.
17. Use agentic AI for routine work while treating data security as a primary product requirement. A single security failure can compromise trust in the entire application.
18. Take architecture ownership for an enterprise platform capable of millions of users. Relationship trees may contain hundreds of nodes and each user may have dozens of circles.
19. Make independent, technically sound decisions across design, development, testing, cloud deployment, web, mobile, APIs, and GitHub delivery. Work in goal mode.
20. Store all product-owner chats in one repository file for future reference.

## Referenced Screenshot Context

- Feed attachments rendered as a generic `View or download document` button for MP3 files and downloaded immediately.
- Dashboard and profile screens remained indefinitely on `Loading your network...` or `Loading profile...`.
- Sidebar initially lacked sign-out and showed `Private by design`; a later sign-out stayed on `Signing out...`.
- Health records showed HTTP 403.
- The operating-system file picker filtered out MP3 while a private-message attachment showed a PDF card.
- Global search incorrectly routed to a circle-only search screen, then produced `Internal Server Error`.
- Sign-in failed after server/database state changed.

## Verbatim User Message Transcript

> Please find anywhere in the entire application CircleNet-AI ?? If yes, please replace with MyAaptha ... And in GitHub also, replace with MyAaptha only... replace with MyAaptha only.. Please allow to upload report, after uploading the report with using AI, read report and give your charts/graphs, analysis of report ... (no user have that much patience to add each recod from the report)... the system should take this work ... Ex: Lipid profile - have atleast 10 parameters, CBP have 10 parameters like that ... after uploading entire reports, you need to track, on which date how much value, and how it is trend ... and few suggestions to reduce the levels if the user cross nomal levels ...

> Push to github ...

> https://github.com/username/MyAaptha.git

> https://github.com/your-actual-username/MyAaptha.git Push

> https://github.com/SreeS31/MyAaptha push

> option 1

> Here it self play audio/ video, until he want to download ... now it's asking directly download .... First click, it should play/ open document in view format ... if it right click on that or on top dorpdown arrow, show the options. Like WhatsApp, all possible options/menues should bring to the document/audio/video ...

> Check my previous message, not implemented ... just now uploaded one file, directly it is going for download ... not play mode ....

> not loading frontend ... check it please

> Not loading again ... Left corner down, why this word private by design ?? Remove it.. Where is logout/signout button ?? I can't find it ...

> Nothing is loading, singout also not working ... check it

> Request failed ... please check it

> Mp3 is not allowing to upload ... we need to upload all possible file formarts ... documents/audio/video/pdf/excel etc...

> weekly usage limit is available na ... use it...

> Mp3 is not allowing to upload ... we need to upload all possible file formarts ... documents/audio/video/pdf/excel etc...

> Search is not working .... It should give full search if we do on top search bar ... irrespective of relationship, circles, private chat ... wherever that word matches, it should give all ... the bottom search is page wise, that should search within that page only ...

> Some error came, please check

> please check server

> why temparory database ?? Create a permanent database in system and later we can push it to cloud .... the database should be permanent in local system (mysql or postreg) ... I clearly mentioned in the initial stage ....

> I pressed singout but since 2 min... it shows like that ... action is pending only...

> Good morning, Please do a client side validation and server side validation of each and every feild of every form and every page in entire application even search feild also ... Any data brought from user, first we need to do server side validation then only do the next action ... This will avoid 80% problems like hacking/unnecessary data into server, etc... This should be done for web, mobile and every API...

> All uploads should be verified strictly and check every upload weather it is a Script/malware or unnecssary file ? or Exe file ?? We should avoid all those and check for Security angle of all uploads before storing in our server .... 100% secure our server with all uploads/form data at server side and client side also ... We should secure our server a high priority... we have so many uploads, so we should more and more careful....

> UI/UX should be excellent, it should be Enterprise level application and user may increase millions also... So use the fonts/font family should be more and more attractive and colours also very attractive (light colours) ....

> Mobile, web, everything should be similar and they should not find any dificult to get the menu items and UI/UX should be same ...

> Good morning, Is there anything I missed in this application which is good to implement ?? You think about the upcoming next 10 years requirements of people and design the application, for Social communications with the Relatives, Friends, Followers, goals, life settlements, Documents management, required advices for Health, Wealth goals, AI suggestions in every area... We need to use AI extensively to readuce human work and impove felibility to users .... We are developing the application in 2026 for next 10 years and now AI in advanced mode like Agentic AI is popular now, which means, AI can do all our routine works ... so our application should be benifited with this AI Agentic .... One more important point in this era, is Data Security... now every one fears about the Data Security, if single mistake entire application will be comprimised ... I am also having that fear ... because of this, I am asking N number of times about security of the applications.... Please take a Archtect role and design the application as a Enterperise level (it should sustain for millions of users).... Relationship Tree may increase to few hundreads of nodes ... Circles may go few dozens for each user... So design, develop, test, deploy (cloud AWS/GCP etc..) every where use your full knowledge in this application .... no need to give instructions from my side... take your own decisions which is good for our application... Go ahead as a Goal mode... Sync web, mobile, API and final code push to GitHub.... And please write all my chats into one File and Store, so in future reference purpose it will use.

## Record-Keeping Rule

This file contains product requirements, not credentials, tokens, private health documents, or other secrets. Future chat entries must be appended with a date and must redact authentication secrets and personal data before commit.
