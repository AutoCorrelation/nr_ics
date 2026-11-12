function r = extract_pilots(x,y,pci)
%EXTRACT_PILOTS Keep transmitted and received pilots distinct.
validateattributes(x,{'numeric'},{'size',[240 4]});
assert(size(y,1)==240 && size(y,2)==4,'Invalid received grid shape.');
a=ssb.layout(pci);
n=size(y,3); y=reshape(y,960,n);
r=struct('coords',a.dmrs_kl,'ideal',x(a.dmrs_ind), ...
    'received',y(a.dmrs_ind,:),'ls',y(a.dmrs_ind,:)./x(a.dmrs_ind));
end
