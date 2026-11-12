function validate_metadata(pci,index,lmax,listLength,ibar)
%VALIDATE_METADATA Reject ambiguous or unsupported BCH configuration.
if nargin<5, ibar=[]; end
if ~integerScalar(pci,0,1007)
    error('ssb:InvalidMetadata','PCI must be an integer scalar in 0..1007.');
end
if ~integerScalar(lmax,4,8) || ~ismember(lmax,[4 8])
    error('ssb:InvalidMetadata','Lmax must be 4 or 8.');
end
if ~integerScalar(index,0,lmax-1)
    error('ssb:InvalidMetadata','SSB index must be an integer scalar in 0..Lmax-1.');
end
if ~integerScalar(listLength,1,flintmax) || floor(log2(double(listLength)))~=log2(double(listLength))
    error('ssb:InvalidMetadata','List length must be a positive integer power of two.');
end
if nargin>=5
    if ~integerScalar(ibar,0,7) || ...
            (lmax==8 && ibar~=index) || (lmax==4 && mod(ibar,4)~=index)
        error('ssb:InvalidMetadata','ibar_ssb is inconsistent with Lmax and SSB index.');
    end
end
end

function ok = integerScalar(value,minimum,maximum)
ok=isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) && ...
    value==fix(value) && value>=minimum && value<=maximum;
end
