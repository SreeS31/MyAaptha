import {ReactNode} from 'react';
export default function ActionDisclosure({title,children}:{title:string;children:ReactNode}){
  return <details className="action-disclosure"><summary><span aria-hidden="true">+</span>{title}</summary><div className="action-disclosure-body">{children}</div></details>;
}
