import{p as U}from"./chunk-K2ZEYYM2-Dkc748ii.js";import{p as V}from"./treemap-KMMF4GRG-YVX6V4UE-DMn6bASe.js";import{b as s,g as Z,s as j,c as q,d as H,y as J,x as K,l as w,e as Q,I as X,aP as Y,aR as ee,aS as G,aT as te,h as ae,C as re,aU as ie,L as se}from"./Mermaid.vue_vue_type_script_setup_true_lang-CU0L-Mwi.js";import"./chunk-ZZTYOBSU--L3Z1bQX.js";import"./index-DI_DOcdB.js";import"./modules/vue-O7xnxuhf.js";import"./modules/shiki-B1XjtbWZ.js";import"./slidev/context-Bv1uIFmY.js";import"./modules/file-saver-yovgVCbS.js";var le=se.pie,C={sections:new Map,showData:!1},g=C.sections,D=C.showData,oe=structuredClone(le),ne=s(()=>structuredClone(oe),"getConfig"),ce=s(()=>{g=new Map,D=C.showData,re()},"clear"),pe=s(({label:e,value:a})=>{if(a<0)throw new Error(`"${e}" has invalid value: ${a}. Negative values are not allowed in pie charts. All slice values must be >= 0.`);g.has(e)||(g.set(e,a),w.debug(`added new section: ${e}, with value: ${a}`))},"addSection"),de=s(()=>g,"getSections"),ge=s(e=>{D=e},"setShowData"),ue=s(()=>D,"getShowData"),P={getConfig:ne,clear:ce,setDiagramTitle:K,getDiagramTitle:J,setAccTitle:H,getAccTitle:q,setAccDescription:j,getAccDescription:Z,addSection:pe,getSections:de,setShowData:ge,getShowData:ue},fe=s((e,a)=>{U(e,a),a.setShowData(e.showData),e.sections.map(a.addSection)},"populateDb"),he={parse:s(async e=>{const a=await V("pie",e);w.debug(a),fe(a,P)},"parse")},me=s(e=>`
  .pieCircle{
    stroke: ${e.pieStrokeColor};
    stroke-width : ${e.pieStrokeWidth};
    opacity : ${e.pieOpacity};
  }
  .pieOuterCircle{
    stroke: ${e.pieOuterStrokeColor};
    stroke-width: ${e.pieOuterStrokeWidth};
    fill: none;
  }
  .pieTitleText {
    text-anchor: middle;
    font-size: ${e.pieTitleTextSize};
    fill: ${e.pieTitleTextColor};
    font-family: ${e.fontFamily};
  }
  .slice {
    font-family: ${e.fontFamily};
    fill: ${e.pieSectionTextColor};
    font-size:${e.pieSectionTextSize};
    // fill: white;
  }
  .legend text {
    fill: ${e.pieLegendTextColor};
    font-family: ${e.fontFamily};
    font-size: ${e.pieLegendTextSize};
  }
`,"getStyles"),ve=me,Se=s(e=>{const a=[...e.values()].reduce((r,l)=>r+l,0),y=[...e.entries()].map(([r,l])=>({label:r,value:l})).filter(r=>r.value/a*100>=1).sort((r,l)=>l.value-r.value);return ie().value(r=>r.value)(y)},"createPieArcs"),xe=s((e,a,y,$)=>{w.debug(`rendering pie chart
`+e);const r=$.db,l=Q(),T=X(r.getConfig(),l.pie),A=40,o=18,p=4,c=450,u=c,f=Y(a),n=f.append("g");n.attr("transform","translate("+u/2+","+c/2+")");const{themeVariables:i}=l;let[_]=ee(i.pieOuterStrokeWidth);_??(_=2);const b=T.textPosition,d=Math.min(u,c)/2-A,R=G().innerRadius(0).outerRadius(d),W=G().innerRadius(d*b).outerRadius(d*b);n.append("circle").attr("cx",0).attr("cy",0).attr("r",d+_/2).attr("class","pieOuterCircle");const h=r.getSections(),I=Se(h),L=[i.pie1,i.pie2,i.pie3,i.pie4,i.pie5,i.pie6,i.pie7,i.pie8,i.pie9,i.pie10,i.pie11,i.pie12];let m=0;h.forEach(t=>{m+=t});const E=I.filter(t=>(t.data.value/m*100).toFixed(0)!=="0"),v=te(L);n.selectAll("mySlices").data(E).enter().append("path").attr("d",R).attr("fill",t=>v(t.data.label)).attr("class","pieCircle"),n.selectAll("mySlices").data(E).enter().append("text").text(t=>(t.data.value/m*100).toFixed(0)+"%").attr("transform",t=>"translate("+W.centroid(t)+")").style("text-anchor","middle").attr("class","slice"),n.append("text").text(r.getDiagramTitle()).attr("x",0).attr("y",-400/2).attr("class","pieTitleText");const k=[...h.entries()].map(([t,x])=>({label:t,value:x})),S=n.selectAll(".legend").data(k).enter().append("g").attr("class","legend").attr("transform",(t,x)=>{const F=o+p,O=F*k.length/2,N=12*o,B=x*F-O;return"translate("+N+","+B+")"});S.append("rect").attr("width",o).attr("height",o).style("fill",t=>v(t.label)).style("stroke",t=>v(t.label)),S.append("text").attr("x",o+p).attr("y",o-p).text(t=>r.getShowData()?`${t.label} [${t.value}]`:t.label);const M=Math.max(...S.selectAll("text").nodes().map(t=>(t==null?void 0:t.getBoundingClientRect().width)??0)),z=u+A+o+p+M;f.attr("viewBox",`0 0 ${z} ${c}`),ae(f,c,z,T.useMaxWidth)},"draw"),we={draw:xe},ke={parser:he,db:P,renderer:we,styles:ve};export{ke as diagram};
