import {displayCopy} from '../lib/display-copy';
type Item = {label:string;value:number};
export default function InsightBars({title,items,emptyLabel=displayCopy.noData,formatValue=(value:number)=>String(value)}:{title?:string;emptyLabel?:string;items:Item[];formatValue?:(value:number)=>string}) {
 const values=items.filter(item=>Number.isFinite(item.value)&&item.value>=0);
 const max=Math.max(1,...values.map(item=>item.value));
 return <section className="insight-chart">{title&&<header><h3>{title}</h3></header>}{values.some(item=>item.value>0)?<ul className="insight-bars">{values.map((item,index)=><li key={`${item.label}-${index}`}><div><span>{item.label}</span><strong>{formatValue(item.value)}</strong></div><span className="insight-track" aria-hidden="true"><i style={{width:`${item.value/max*100}%`,background:`var(--chart-${index%5})`}}/></span></li>)}</ul>:<p className="insight-empty">{emptyLabel}</p>}</section>;
}
