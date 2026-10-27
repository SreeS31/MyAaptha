type Item = {label:string;value:number};
export default function InsightBars({title,description,items,formatValue=(value:number)=>String(value)}:{title:string;description:string;items:Item[];formatValue?:(value:number)=>string}) {
 const values=items.filter(item=>Number.isFinite(item.value)&&item.value>=0);
 const max=Math.max(1,...values.map(item=>item.value));
 return <section className="insight-chart"><header><h3>{title}</h3><p>{description}</p></header>{values.some(item=>item.value>0)?<ul className="insight-bars">{values.map((item,index)=><li key={`${item.label}-${index}`}><div><span>{item.label}</span><strong>{formatValue(item.value)}</strong></div><span className="insight-track" aria-hidden="true"><i style={{width:`${item.value/max*100}%`,background:`var(--chart-${index%5})`}}/></span></li>)}</ul>:<p className="insight-empty">Your chart will appear when you add data.</p>}</section>;
}
