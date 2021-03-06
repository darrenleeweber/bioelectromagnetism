function uniqueFaceIndexList=findUniqueFaceIndexList(mesh);
%   uniqueFaceIndexList=findUniqueFaceIndexList(mesh);
%   The original mesh has many points that are duplicates : they are listed because they are
%   members of several distinct faces or striplists. 
%   Here we create the structure mesh.uniqueFaceIndexList which defines all the triangular faces in 
%   the mesh in terms of uniquely-defined vertices with no duplicates.
%   mesh.uniqueFaceIndexList is nFaces*3 in size. Each triplet of indices references three points in 
%   mesh.uniqueVertices and defines a single triangular face in the mesh.
%  AUTHOR:  Wade
%  DATE: Last modified 020701


uniqueFaceIndexList(:,1)=mesh.UniqueToVerts(mesh.faceIndexList(:,1));
uniqueFaceIndexList(:,2)=mesh.UniqueToVerts(mesh.faceIndexList(:,2));
uniqueFaceIndexList(:,3)=mesh.UniqueToVerts(mesh.faceIndexList(:,3));

nFaces=length(uniqueFaceIndexList);

% almost there but....
% Could (in theory) have duplicates of same face in either the same, or a permuted order
% Run through the list and sort so they're low to high
uniqueFaceIndexList=sort(uniqueFaceIndexList,2);
% Now eliminate duplicates
uniqueFaceIndexList=unique(uniqueFaceIndexList,'rows');

fEliminated=(length(uniqueFaceIndexList)-nFaces);

if (fEliminated)
    fprintf ('\n%d  faces eliminated in function: findUniqueFaceIndexList',fEliminated);
    % mrGray seems to produce meshes with no redundant faces at the moment but this is a useful check.
end


return;
