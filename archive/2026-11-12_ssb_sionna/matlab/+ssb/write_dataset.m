function write_dataset(path,name,value,shape)
%WRITE_DATASET Explicit MATLAB dimension order; shape is MATLAB order.
if nargin<4, shape=size(value); end
h5create(path,name,shape,'Datatype',class(value));
if isscalar(shape)
    h5write(path,name,value(:));
else
    h5write(path,name,reshape(value,shape));
end
end
