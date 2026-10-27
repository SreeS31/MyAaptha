import {ReactNode} from 'react';
import InfoTip from './InfoTip';
export default function PageHeading({title,help,actions,meta}:{title:string;help?:ReactNode;actions?:ReactNode;meta?:ReactNode}){
  return <header className="page-heading"><div className="page-heading-title"><h1>{title}</h1>{meta&&<span className="page-heading-count">{meta}</span>}{help&&<InfoTip label={`About ${title.toLowerCase()}`}>{help}</InfoTip>}</div>{actions&&<div className="page-heading-actions">{actions}</div>}</header>;
}
