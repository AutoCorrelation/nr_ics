function a = layout(pci)
%LAYOUT Return ordered zero-based coordinates and disjoint resource classes.
validateattributes(pci,{'numeric'},{'scalar','integer','>=',0,'<=',1007});
opts = {'IndexStyle','subscript','IndexBase','0based'};
[pb,info] = nrPBCHIndices(pci,opts{:});
coords = {nrPSSIndices(opts{:}),nrSSSIndices(opts{:}), ...
    nrPBCHDMRSIndices(pci,opts{:}),pb};
names = {'pss','sss','dmrs','pbch'};
a.class_id = zeros(240,4,'uint8');
for k = 1:4
    c = double(coords{k});
    assert(all(c(:,3)==0));
    c = c(:,1:2);
    ind = c(:,1)+240*c(:,2)+1;
    assert(issorted(ind) && numel(unique(ind))==numel(ind));
    assert(all(a.class_id(ind)==0));
    a.([names{k} '_kl']) = int32(c);
    a.([names{k} '_ind']) = ind;
    a.class_id(ind) = k;
end
assert(isequal(cellfun(@(x) size(x,1),coords),[127 127 144 432]));
assert(nnz(a.class_id==0)==130 && info.G==864 && info.Gd==432);
a.mask_dmrs = a.class_id==3;
a.mask_pbch = a.class_id==4;
a.mask_active = a.class_id~=0;
a.info = info;
end
