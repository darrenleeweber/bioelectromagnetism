function [ avw, machine ] = avw_img_read_4d(fileprefix,volIndex,IMGorient,machine)

% avw_img_read - read Analyze format data image (*.img)
% 
% [ avw, machine ] = avw_img_read(fileprefix, [volIndex], [orient], [machine])
% 
% fileprefix - a string, the filename without the .img extension
% 
% volIndex - the volume to read from a 4D file, where the first volume
%            has index 1 (the default)
% 
% orient - read a specified orientation, integer values:
% 
%          '', use header history orient field
%          0,  transverse unflipped (LAS*)
%          1,  coronal unflipped (LA*S)
%          2,  sagittal unflipped (L*AS)
%          3,  transverse flipped (LPS*)
%          4,  coronal flipped (LA*I)
%          5,  sagittal flipped (L*AI)
% 
% where * follows the slice dimension and letters indicate +XYZ
% orientations (L left, R right, A anterior, P posterior,
% I inferior, & S superior).
% 
% Some files may contain data in the 3-5 orientations, but this
% is unlikely. For more information about orientation, see the
% documentation at the end of this .m file.  See also the 
% AVW_FLIP function for orthogonal reorientation.
% 
% machine - a string, see machineformat in fread for details.
%           The default here is 'ieee-le' but the routine
%           will automatically switch between little and big
%           endian to read any such Analyze header.  It
%           reports the appropriate machine format and can
%           return the machine value.
% 
% Returned values:
% 
% avw.hdr - a struct with image data parameters.
% avw.img - a 3D matrix of image data (double precision) 
%           from a volume of a 4D Analyze file
% 
% The returned 3D matrix will correspond with the 
% default ANALYZE coordinate system, which 
% is Left-handed:
% 
% X-Y plane is Transverse
% X-Z plane is Coronal
% Y-Z plane is Sagittal
% 
% X axis runs from patient right (low X) to patient Left (high X)
% Y axis runs from posterior (low Y) to Anterior (high Y)
% Z axis runs from inferior (low Z) to Superior (high Z)
% 
% See also: avw_hdr_read (called by this function), 
%           avw_view, avw_write, avw_img_write, avw_flip
% 


% $Revision: 1.1 $ $Date: 2004/11/12 01:30:25 $

% Licence:  GNU GPL, no express or implied warranties
% History:  05/2002, Darren.Weber@flinders.edu.au
%                    The Analyze format is copyright 
%                    (c) Copyright, 1986-1995
%                    Biomedical Imaging Resource, Mayo Foundation
%           01/2003, Darren.Weber@flinders.edu.au
%                    - adapted for matlab v5
%                    - revised all orientation information and handling 
%                      after seeking further advice from AnalyzeDirect.com
%           03/2003, Darren.Weber@flinders.edu.au
%                    - adapted for -ve pixdim values (non standard Analyze)
%           11/2003, Darren.Weber_at_radiology.ucsf.edu
%                    - adapted for 4D Analyze files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


error('in development');


if ~exist('fileprefix','var'),
    msg = sprintf('...no input fileprefix - see help avw_img_read\n\n');
    error(msg);
end
if ~exist('volIndex','var'), volIndex = 1; end
if ~exist('IMGorient','var'), IMGorient = ''; end
if ~exist('machine','var'), machine = 'ieee-le'; end

if findstr('.hdr',fileprefix),
    fileprefix = strrep(fileprefix,'.hdr','');
end
if findstr('.img',fileprefix),
    fileprefix = strrep(fileprefix,'.img','');
end

% MAIN

% Read the file header
[ avw, machine ] = avw_hdr_read(fileprefix,machine);

avw = read_image(avw,volIndex,IMGorient,machine);

return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ avw ] = read_image(avw,volIndex,IMGorient,machine)

fid = fopen(sprintf('%s.img',avw.fileprefix),'r',machine);
if fid < 0,
  msg = sprintf('...cannot open file %s.img\n\n',avw.fileprefix);
  error(msg);
end

version = '[$Revision: 1.1 $]';
fprintf('\nAVW_IMG_READ [v%s]\n',version(12:16));  tic;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% check data precision

% short int bitpix;    /* Number of bits per pixel; 1, 8, 16, 32, or 64. */ 
% short int datatype      /* Datatype for this image set */ 
% /*Acceptable values for datatype are*/ 
% #define DT_NONE             0
% #define DT_UNKNOWN          0    /*Unknown data type*/ 
% #define DT_BINARY           1    /*Binary             ( 1 bit per voxel)*/ 
% #define DT_UNSIGNED_CHAR    2    /*Unsigned character ( 8 bits per voxel)*/ 
% #define DT_SIGNED_SHORT     4    /*Signed short       (16 bits per voxel)*/ 
% #define DT_SIGNED_INT       8    /*Signed integer     (32 bits per voxel)*/ 
% #define DT_FLOAT           16    /*Floating point     (32 bits per voxel)*/ 
% #define DT_COMPLEX         32    /*Complex (64 bits per voxel; 2 floating point numbers)/* 
% #define DT_DOUBLE          64    /*Double precision   (64 bits per voxel)*/ 
% #define DT_RGB            128    /*A Red-Green-Blue datatype*/
% #define DT_ALL            255    /*Undocumented*/

switch double(avw.hdr.dime.bitpix),
  case  1,   precision = 'bit1';
  case  8,   precision = 'uchar';
  case 16,   precision = 'int16';
  case 32,
    if     isequal(avw.hdr.dime.datatype, 8), precision = 'int32';
    else                                      precision = 'single';
    end
  case 64,   precision = 'double';
  otherwise,
    precision = 'uchar';
    fprintf('...precision undefined in header, using ''uchar''\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculate the byte index range for a volume to be read
% In general, voxel(a,b,c) will be stored as byte N where
% N = a + Nx(b + Ny*c), given the first voxel of the image
% is (0,0,0).  Matlab fseek command indexes the first voxel
% as (0,0,0), so this formula should work.

Nx = double(avw.hdr.dime.dim(2));
Ny = double(avw.hdr.dime.dim(3));
Nz = double(avw.hdr.dime.dim(4));
Nt = double(avw.hdr.dime.dim(5));

readPixels = Nx * Ny * Nz;

bitpix = double(avw.hdr.dime.bitpix);

if Nt == 1,
  fprintf('...reading volume %d of %d\n',1,Nt);
  avw.offset = 0;
else
  if volIndex <= Nt,
    fprintf('...reading volume %d of %d\n',volIndex,Nt);
    avw.offset = (readPixels * volIndex) - readPixels;
    % this the offset in pixels, but we need bytes for fseek!
    avw.offset = (avw.offset * bitpix) / 8;
    
  else
    msg = sprintf('volIndex > 4D volume (%d vols)',Nt);
    error(msg);
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read a volume from the .img file into matlab
fprintf('...reading %s Analyze %s image format.\n',machine,precision);
fseek(fid,avw.offset,'bof');
% adjust for matlab version
ver = version;
ver = str2num(ver(1));
if ver < 6,
  tmp = fread(fid,readPixels,sprintf('%s',precision));
else,

  ftell(fid)
  
  
  [tmp, count] = fread(fid,readPixels,sprintf('%s=>double',precision));
  
  
  ftell(fid)
  
  avw.offset = (readPixels * [volIndex + 1]) - readPixels;
  avw.offset = (avw.offset * bitpix) / 8
  
  
  if count ~= readPixels,
    msg = sprintf('only read %d of %d total pixels',count,readPixels);
    error(msg);
  end
end
fclose(fid);

% Update the global min and max values
avw.hdr.dime.glmax = max(double(tmp));
avw.hdr.dime.glmin = min(double(tmp));


%---------------------------------------------------------------
% Now partition the img data into xyz

% --- first figure out the size of the image

% short int dim[ ];      /* Array of the image dimensions */ 
%
% dim[0]      Number of dimensions in database; usually 4. 
% dim[1]      Image X dimension;  number of pixels in an image row. 
% dim[2]      Image Y dimension;  number of pixel rows in slice. 
% dim[3]      Volume Z dimension; number of slices in a volume. 
% dim[4]      Time points; number of volumes in database.

PixelDim = double(avw.hdr.dime.dim(2));
RowDim   = double(avw.hdr.dime.dim(3));
SliceDim = double(avw.hdr.dime.dim(4));

PixelSz  = double(avw.hdr.dime.pixdim(2));
RowSz    = double(avw.hdr.dime.pixdim(3));
SliceSz  = double(avw.hdr.dime.pixdim(4));





% ---- NON STANDARD ANALYZE...

% Some Analyze files have been found to set -ve pixdim values, eg
% the MNI template avg152T1_brain in the FSL etc/standard folder,
% perhaps to indicate flipped orientation?  If so, this code below
% will NOT handle the flip correctly!
if PixelSz < 0,
    warning('X pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(2))');
    PixelSz = abs(PixelSz);
    avw.hdr.dime.pixdim(2) = single(PixelSz);
end
if RowSz < 0,
    warning('Y pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(3))');
    RowSz = abs(RowSz);
    avw.hdr.dime.pixdim(3) = single(RowSz);
end
if SliceSz < 0,
    warning('Z pixdim < 0 !!! resetting to abs(avw.hdr.dime.pixdim(4))');
    SliceSz = abs(SliceSz);
    avw.hdr.dime.pixdim(4) = single(SliceSz);
end

% ---- END OF NON STANDARD ANALYZE





% --- check the orientation specification and arrange img accordingly
if ~isempty(IMGorient),
  if ischar(IMGorient),
    avw.hdr.hist.orient = uint8(str2num(IMGorient));
  else
    avw.hdr.hist.orient = uint8(IMGorient);
  end
end,

if isempty(avw.hdr.hist.orient),
  msg = [ '...unspecified avw.hdr.hist.orient, using default 0\n',...
      '   (check image and try explicit IMGorient option).\n'];
  fprintf(msg);
  avw.hdr.hist.orient = uint8(0);
end

switch double(avw.hdr.hist.orient),
  
  case 0, % transverse unflipped
    
    % orient = 0:  The primary orientation of the data on disk is in the
    % transverse plane relative to the object scanned.  Most commonly, the fastest
    % moving index through the voxels that are part of this transverse image would
    % span the right->left extent of the structure imaged, with the next fastest
    % moving index spanning the posterior->anterior extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
    % being the slice direction.
    
    % For the 'transverse unflipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to left
    % Rows in   'y' axis                  - from patient posterior to anterior
    % Slices in 'z' axis                  - from patient inferior to superior
    
    fprintf('...reading axial unflipped orientation\n');
    
    avw.img = zeros(PixelDim,RowDim,SliceDim);
    
    n = 1;
    x = 1:PixelDim;
    for z = 1:SliceDim,
      for y = 1:RowDim,
        % load Y row of X values into Z slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % no need to rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    
    
  case 1, % coronal unflipped
    
    % orient = 1:  The primary orientation of the data on disk is in the coronal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this coronal image would span the
    % right->left extent of the structure imaged, with the next fastest moving
    % index spanning the inferior->superior extent of the structure.  This 'orient'
    % flag would indicate to Analyze that this data should be placed in the X-Z
    % plane of the 3D Analyze Coordinate System, with the Y dimension being the
    % slice direction.
    
    % For the 'coronal unflipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to left
    % Rows in   'z' axis                  - from patient inferior to superior
    % Slices in 'y' axis                  - from patient posterior to anterior
    
    fprintf('...reading coronal unflipped orientation\n');
    
    avw.img = zeros(PixelDim,SliceDim,RowDim);
    
    n = 1;
    x = 1:PixelDim;
    for y = 1:SliceDim,
      for z = 1:RowDim,
        % load Z row of X values into Y slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([PixelDim,SliceDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([PixelSz,SliceSz,RowSz]);
    
    
  case 2, % sagittal unflipped
    
    % orient = 2:  The primary orientation of the data on disk is in the sagittal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this sagittal image would span the
    % posterior->anterior extent of the structure imaged, with the next fastest
    % moving index spanning the inferior->superior extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
    % being the slice direction.
    
    % For the 'sagittal unflipped' type, the voxels are stored with
    % Pixels in 'y' axis (varies fastest) - from patient posterior to anterior
    % Rows in   'z' axis                  - from patient inferior to superior
    % Slices in 'x' axis                  - from patient right to left
    
    fprintf('...reading sagittal unflipped orientation\n');
    
    avw.img = zeros(SliceDim,PixelDim,RowDim);
    
    n = 1;
    y = 1:PixelDim;         % posterior to anterior (fastest)
    
    for x = 1:SliceDim,     % right to left (slowest)
      for z = 1:RowDim,   % inferior to superior
        
        % load Z row of Y values into X slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([SliceDim,PixelDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([SliceSz,PixelSz,RowSz]);
    
    
    %--------------------------------------------------------------------------------
    % Orient values 3-5 have the second index reversed in order, essentially
    % 'flipping' the images relative to what would most likely become the vertical
    % axis of the displayed image.
    %--------------------------------------------------------------------------------
    
  case 3, % transverse/axial flipped
    
    % orient = 3:  The primary orientation of the data on disk is in the
    % transverse plane relative to the object scanned.  Most commonly, the fastest
    % moving index through the voxels that are part of this transverse image would
    % span the right->left extent of the structure imaged, with the next fastest
    % moving index spanning the *anterior->posterior* extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
    % being the slice direction.
    
    % For the 'transverse flipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to Left
    % Rows in   'y' axis                  - from patient anterior to Posterior *
    % Slices in 'z' axis                  - from patient inferior to Superior
    
    fprintf('...reading axial flipped (+Y from Anterior to Posterior)\n');
    
    avw.img = zeros(PixelDim,RowDim,SliceDim);
    
    n = 1;
    x = 1:PixelDim;
    for z = 1:SliceDim,
      for y = RowDim:-1:1, % flip in Y, read A2P file into P2A 3D matrix
        
        % load a flipped Y row of X values into Z slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % no need to rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    
    
  case 4, % coronal flipped
    
    % orient = 4:  The primary orientation of the data on disk is in the coronal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this coronal image would span the
    % right->left extent of the structure imaged, with the next fastest moving
    % index spanning the *superior->inferior* extent of the structure.  This 'orient'
    % flag would indicate to Analyze that this data should be placed in the X-Z
    % plane of the 3D Analyze Coordinate System, with the Y dimension being the
    % slice direction.
    
    % For the 'coronal flipped' type, the voxels are stored with
    % Pixels in 'x' axis (varies fastest) - from patient right to Left
    % Rows in   'z' axis                  - from patient superior to Inferior*
    % Slices in 'y' axis                  - from patient posterior to Anterior
    
    fprintf('...reading coronal flipped (+Z from Superior to Inferior)\n');
    
    avw.img = zeros(PixelDim,SliceDim,RowDim);
    
    n = 1;
    x = 1:PixelDim;
    for y = 1:SliceDim,
      for z = RowDim:-1:1, % flip in Z, read S2I file into I2S 3D matrix
        
        % load a flipped Z row of X values into Y slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([PixelDim,SliceDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([PixelSz,SliceSz,RowSz]);
    
    
  case 5, % sagittal flipped
    
    % orient = 5:  The primary orientation of the data on disk is in the sagittal
    % plane relative to the object scanned.  Most commonly, the fastest moving
    % index through the voxels that are part of this sagittal image would span the
    % posterior->anterior extent of the structure imaged, with the next fastest
    % moving index spanning the *superior->inferior* extent of the structure.  This
    % 'orient' flag would indicate to Analyze that this data should be placed in
    % the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
    % being the slice direction.
    
    % For the 'sagittal flipped' type, the voxels are stored with
    % Pixels in 'y' axis (varies fastest) - from patient posterior to Anterior
    % Rows in   'z' axis                  - from patient superior to Inferior*
    % Slices in 'x' axis                  - from patient right to Left
    
    fprintf('...reading sagittal flipped (+Z from Superior to Inferior)\n');
    
    avw.img = zeros(SliceDim,PixelDim,RowDim);
    
    n = 1;
    y = 1:PixelDim;
    
    for x = 1:SliceDim,
      for z = RowDim:-1:1, % flip in Z, read S2I file into I2S 3D matrix
        
        % load a flipped Z row of Y values into X slice avw.img
        avw.img(x,y,z) = tmp(n:n+(PixelDim-1));
        n = n + PixelDim;
      end
    end
    
    % rearrange avw.hdr.dime.dim or avw.hdr.dime.pixdim
    avw.hdr.dime.dim(2:4) = int16([SliceDim,PixelDim,RowDim]);
    avw.hdr.dime.pixdim(2:4) = single([SliceSz,PixelSz,RowSz]);
    
  otherwise
    
    error('unknown value in avw.hdr.hist.orient, try explicit IMGorient option.');
    
end

t=toc; fprintf('...done (%5.2f sec).\n\n',t);

return




% This function attempts to read the orientation of the
% Analyze file according to the hdr.hist.orient field of the 
% header.  Unfortunately, this field is optional and not
% all programs will set it correctly, so there is no guarantee,
% that the data loaded will be correctly oriented.  If necessary, 
% experiment with the 'orient' option to read the .img 
% data into the 3D matrix of avw.img as preferred.
% 

% (Conventions gathered from e-mail with support@AnalyzeDirect.com)
% 
% 0  transverse unflipped 
%       X direction first,  progressing from patient right to left, 
%       Y direction second, progressing from patient posterior to anterior, 
%       Z direction third,  progressing from patient inferior to superior. 
% 1  coronal unflipped 
%       X direction first,  progressing from patient right to left, 
%       Z direction second, progressing from patient inferior to superior, 
%       Y direction third,  progressing from patient posterior to anterior. 
% 2  sagittal unflipped 
%       Y direction first,  progressing from patient posterior to anterior, 
%       Z direction second, progressing from patient inferior to superior, 
%       X direction third,  progressing from patient right to left. 
% 3  transverse flipped 
%       X direction first,  progressing from patient right to left, 
%       Y direction second, progressing from patient anterior to posterior, 
%       Z direction third,  progressing from patient inferior to superior. 
% 4  coronal flipped 
%       X direction first,  progressing from patient right to left, 
%       Z direction second, progressing from patient superior to inferior, 
%       Y direction third,  progressing from patient posterior to anterior. 
% 5  sagittal flipped 
%       Y direction first,  progressing from patient posterior to anterior, 
%       Z direction second, progressing from patient superior to inferior, 
%       X direction third,  progressing from patient right to left. 


%----------------------------------------------------------------------------
% From ANALYZE documentation...
% 
% The ANALYZE coordinate system has an origin in the lower left 
% corner. That is, with the subject lying supine, the coordinate 
% origin is on the right side of the body (x), at the back (y), 
% and at the feet (z). This means that:
% 
% +X increases from right (R) to left (L)
% +Y increases from the back (posterior,P) to the front (anterior, A)
% +Z increases from the feet (inferior,I) to the head (superior, S)
% 
% The LAS orientation is the radiological convention, where patient 
% left is on the image right.  The alternative neurological
% convention is RAS (also Talairach convention).
% 
% A major advantage of the Analzye origin convention is that the 
% coordinate origin of each orthogonal orientation (transverse, 
% coronal, and sagittal) lies in the lower left corner of the 
% slice as it is displayed.
% 
% Orthogonal slices are numbered from one to the number of slices
% in that orientation. For example, a volume (x, y, z) dimensioned 
% 128, 256, 48 has: 
% 
%   128 sagittal   slices numbered 1 through 128 (X)
%   256 coronal    slices numbered 1 through 256 (Y)
%    48 transverse slices numbered 1 through  48 (Z)
% 
% Pixel coordinates are made with reference to the slice numbers from 
% which the pixels come. Thus, the first pixel in the volume is 
% referenced p(1,1,1) and not at p(0,0,0).
% 
% Transverse slices are in the XY plane (also known as axial slices).
% Sagittal slices are in the ZY plane. 
% Coronal slices are in the ZX plane. 
% 
%----------------------------------------------------------------------------


%----------------------------------------------------------------------------
% E-mail from support@AnalyzeDirect.com
% 
% The 'orient' field in the data_history structure specifies the primary
% orientation of the data as it is stored in the file on disk.  This usually
% corresponds to the orientation in the plane of acquisition, given that this
% would correspond to the order in which the data is written to disk by the
% scanner or other software application.  As you know, this field will contain
% the values:
% 
% orient = 0 transverse unflipped
% 1 coronal unflipped
% 2 sagittal unflipped
% 3 transverse flipped
% 4 coronal flipped
% 5 sagittal flipped
% 
% It would be vary rare that you would ever encounter any old Analyze 7.5
% files that contain values of 'orient' which indicate that the data has been
% 'flipped'.  The 'flipped flag' values were really only used internal to
% Analyze to precondition data for fast display in the Movie module, where the
% images were actually flipped vertically in order to accommodate the raster
% paint order on older graphics devices.  The only cases you will encounter
% will have values of 0, 1, or 2.
% 
% As mentioned, the 'orient' flag only specifies the primary orientation of
% data as stored in the disk file itself.  It has nothing to do with the
% representation of the data in the 3D Analyze coordinate system, which always
% has a fixed representation to the data.  The meaning of the 'orient' values
% should be interpreted as follows:
% 
% orient = 0:  The primary orientation of the data on disk is in the
% transverse plane relative to the object scanned.  Most commonly, the fastest
% moving index through the voxels that are part of this transverse image would
% span the right-left extent of the structure imaged, with the next fastest
% moving index spanning the posterior-anterior extent of the structure.  This
% 'orient' flag would indicate to Analyze that this data should be placed in
% the X-Y plane of the 3D Analyze Coordinate System, with the Z dimension
% being the slice direction.
% 
% orient = 1:  The primary orientation of the data on disk is in the coronal
% plane relative to the object scanned.  Most commonly, the fastest moving
% index through the voxels that are part of this coronal image would span the
% right-left extent of the structure imaged, with the next fastest moving
% index spanning the inferior-superior extent of the structure.  This 'orient'
% flag would indicate to Analyze that this data should be placed in the X-Z
% plane of the 3D Analyze Coordinate System, with the Y dimension being the
% slice direction.
% 
% orient = 2:  The primary orientation of the data on disk is in the sagittal
% plane relative to the object scanned.  Most commonly, the fastest moving
% index through the voxels that are part of this sagittal image would span the
% posterior-anterior extent of the structure imaged, with the next fastest
% moving index spanning the inferior-superior extent of the structure.  This
% 'orient' flag would indicate to Analyze that this data should be placed in
% the Y-Z plane of the 3D Analyze Coordinate System, with the X dimension
% being the slice direction.
% 
% Orient values 3-5 have the second index reversed in order, essentially
% 'flipping' the images relative to what would most likely become the vertical
% axis of the displayed image.
% 
% Hopefully you understand the difference between the indication this 'orient'
% flag has relative to data stored on disk and the full 3D Analyze Coordinate
% System for data that is managed as a volume image.  As mentioned previously,
% the orientation of patient anatomy in the 3D Analyze Coordinate System has a
% fixed orientation relative to each of the orthogonal axes.  This orientation
% is completely described in the information that is attached, but the basics
% are:
% 
% Left-handed coordinate system
% 
% X-Y plane is Transverse
% X-Z plane is Coronal
% Y-Z plane is Sagittal
% 
% X axis runs from patient right (low X) to patient left (high X)
% Y axis runs from posterior (low Y) to anterior (high Y)
% Z axis runs from inferior (low Z) to superior (high Z)
% 
%----------------------------------------------------------------------------



%----------------------------------------------------------------------------
% SPM2 NOTES from spm2 webpage: One thing to watch out for is the image 
% orientation. The proper Analyze format uses a left-handed co-ordinate 
% system, whereas Talairach uses a right-handed one. In SPM99, images were 
% flipped at the spatial normalisation stage (from one co-ordinate system 
% to the other). In SPM2b, a different approach is used, so that either a 
% left- or right-handed co-ordinate system is used throughout. The SPM2b 
% program is told about the handedness that the images are stored with by 
% the spm_flip_analyze_images.m function and the defaults.analyze.flip 
% parameter that is specified in the spm_defaults.m file. These files are 
% intended to be customised for each site. If you previously used SPM99 
% and your images were flipped during spatial normalisation, then set 
% defaults.analyze.flip=1. If no flipping took place, then set 
% defaults.analyze.flip=0. Check that when using the Display facility
% (possibly after specifying some rigid-body rotations) that: 
% 
% The top-left image is coronal with the top (superior) of the head displayed 
% at the top and the left shown on the left. This is as if the subject is viewed 
% from behind. 
% 
% The bottom-left image is axial with the front (anterior) of the head at the 
% top and the left shown on the left. This is as if the subject is viewed from above. 
% 
% The top-right image is sagittal with the front (anterior) of the head at the 
% left and the top of the head shown at the top. This is as if the subject is 
% viewed from the left.
%----------------------------------------------------------------------------
