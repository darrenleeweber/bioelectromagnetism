function hdr = spm_dicom_headers(P)
% Read header information from DICOM files
% FORMAT hdr = spm_dicom_headers(P)
% P   - array of filenames
% hdr - cell array of headers, one element for each file.
%
% Contents of headers are approximately explained in:
% http://medical.nema.org/dicom/2001.html
%
% This code will not work for all cases of DICOM data, as DICOM is an
% extremely complicated "standard".
%
%_______________________________________________________________________
% @(#)spm_dicom_headers.m	2.6 John Ashburner 02/11/12

ver = sscanf(version,'%d');
if ver<6, error('Need Matlab 6.0 or higher for this function.'); end;

dict = readdict;
j    = 0;
hdr  = {};
spm_progress_bar('Init',size(P,1),'Reading DICOM headers','Files complete');
for i=1:size(P,1),
	tmp = readdicomfile(P(i,:),dict);
	if ~isempty(tmp),
		j      = j + 1;
		hdr{j} = tmp;
	end;
	spm_progress_bar('Set',i);
end;
spm_progress_bar('Clear');
return;

function ret = readdicomfile(P,dict)
ret = [];
P   = deblank(P);
fp  = fopen(P,'r','ieee-le');
if fp==-1, warning(['Cant open "' P '".']); return; end;

fseek(fp,128,'bof');
dcm = char(fread(fp,4,'char'))';
if ~strcmp(dcm,'DICM'),
	fclose(fp);
	warning(['"' P '" is not a DICOM file.']);
	return;
end;
ret = read_dicom(fp, 'e',dict);
fclose(fp);
return;
%_______________________________________________________________________

%_______________________________________________________________________
function ret = read_dicom(fp, flg, dict,lim)
if nargin<4, lim=Inf; end;
len = 0;
ret = struct('Filename',fopen(fp));
tag = read_tag(fp,flg,dict);
while ~isempty(tag),
	if tag.length>0,
		switch tag.name,
		case {'GroupLength'},
			% Ignore it
			fseek(fp,tag.length,'cof');
		case {'PixelData'},
			ret.StartOfPixelData = ftell(fp);
			ret.SizeOfPixelData  = tag.length;
			ret.VROfPixelData    = tag.vr;
			fseek(fp,tag.length,'cof');
		case {'CSAData'}, % raw data
			ret.StartOfCSAData = ftell(fp);
			ret.SizeOfCSAData = tag.length;
			fseek(fp,tag.length,'cof');
		case {'CSAImageHeaderInfo', 'CSASeriesHeaderInfo'},
			dat  = decode_csa(fp,tag.length);
			ret  = setfield(ret,tag.name,dat);
		case {'TransferSyntaxUID'},
			dat = char(fread(fp,tag.length,'char'))';
			dat = deblank(dat);
			ret  = setfield(ret,tag.name,dat);
			switch dat,
			case {'1.2.840.10008.1.2'},      % Implicit VR Little Endian
				flg = 'il';
			case {'1.2.840.10008.1.2.1'},    % Explicit VR Little Endian
				flg = 'el';
			case {'1.2.840.10008.1.2.1.99'}, % Deflated Explicit VR Little Endian
				warning(['Cant read Deflated Explicit VR Little Endian file "' fopen(fp) '".']);
				flg = 'dl';
				return;
			case {'1.2.840.10008.1.2.2'},    % Explicit VR Big Endian
				%warning(['Cant read Explicit VR Big Endian file "' fopen(fp) '".']);
				flg = 'eb';
			otherwise,
				warning(['Unknown Transfer Syntax UID for "' fopen(fp) '".']);
				return;
			end;
		otherwise,
			switch tag.vr,
			case {'UN'},
				% Unknown - read as char
				dat = fread(fp,tag.length,'char')';
			case {'AE', 'AS', 'CS', 'DA', 'DS', 'DT', 'IS', 'LO', 'LT',...
				  'PN', 'SH', 'ST', 'TM', 'UI', 'UT'},
				% Character strings
				dat = fread(fp,tag.length,'char')';
				if any(dat<0 | dat>127),
					disp(dat);
					disp(tag.vr);
					disp(tag.name);
				end;
				dat = char(dat);

				switch tag.vr,
				case {'UI','ST'},
					dat = deblank(dat);
				case {'DS'},
					dat = strread(dat,'%f','delimiter','\\')';
				case {'IS'},
					dat = strread(dat,'%d','delimiter','\\')';
				case {'DA'},
					[y,m,d] = strread(dat,'%4d%2d%2d');
					dat     = datenum(y,m,d);
				case {'TM'},
					if any(dat==':'),
						[h,m,s] = strread(dat,'%d:%d:%f');
					else,
						[h,m,s] = strread(dat,'%2d%2d%f');
					end;
					dat = s+60*(m+60*h);
				otherwise,
				end;
			case {'OB'},
				% dont know if this should be signed or unsigned
				dat = fread(fp,tag.length,'char')';
			case {'US', 'AT', 'OW'},
				dat = fread(fp,tag.length/2,'uint16')';
			case {'SS'},
				dat = fread(fp,tag.length/2,'int16')';
			case {'UL'},
				dat = fread(fp,tag.length/4,'uint32')';
			case {'SL'},
				dat = fread(fp,tag.length/4,'int32')';
			case {'FL'},
				dat = fread(fp,tag.length/4,'float')';
			case {'FD'},
				dat = fread(fp,tag.length/8,'double')';
			case {'SQ'},
				dat = read_sq(fp, flg,dict,tag.length);
			otherwise,
				dat = '';
				fseek(fp,tag.length,'cof');
				warning(['Unknown VR "' tag.vr '" in "' fopen(fp) '".']);
			end;
			ret  = setfield(ret,tag.name,dat);
		end;
	end;
	len = len + tag.le + tag.length;
	if len>=lim, break; end;
	tag = read_tag(fp,flg,dict);
end;
return;
%_______________________________________________________________________

%_______________________________________________________________________
function ret = read_sq(fp, flg, dict,lim);
ret = {};
n   = 0;
len = 0;
while len<lim,
	tag.group   = fread(fp,1,'ushort');
	tag.element = fread(fp,1,'ushort');
	tag.length  = fread(fp,1,'uint');
	if tag.length==13, tag.length=10; end;
	len         = len + 8 + tag.length;
	if (tag.group == 65534) & (tag.element == 57344),
		Item   = read_dicom(fp, flg, dict, tag.length);
		Item   = rmfield(Item,'Filename');
		n      = n + 1;
		ret{n} = Item;
	elseif (tag.group == 65534) & (tag.element == 57565),
		break;
	else,
		error([num2str(tag.group) '/' num2str(tag.element) ' unexpected.']);
	end;
end;
return;
%_______________________________________________________________________

%_______________________________________________________________________
function tag = read_tag(fp,flg,dict)
tag.group   = fread(fp,1,'ushort');
tag.element = fread(fp,1,'ushort');
if isempty(tag.element), tag=[]; return; end;
if tag.group == 2, flg = 'el'; end;
t           = dict.tags(tag.group+1,tag.element+1);
if t>0,
	tag.name = dict.values(t).name;
	tag.vr   = dict.values(t).vr{1};
else,
	tag.name = sprintf('Private_%.4x_%.4x',tag.group,tag.element);
	tag.vr   = 'UN';
end;

if flg(2) == 'b',
	[fname,perm,fmt] = fopen(fp);
	if strcmp(fmt,'ieee-le'),
		pos = ftell(fp);
		fclose(fp);
		fp  = fopen(fname,perm,'ieee-be');
		fseek(fp,pos,'bof');
	end;
end;

if flg(1) =='e',
	tag.vr      = char(fread(fp,2,'char'))';
	tag.le      = 6;
	switch tag.vr,
	case {'OB','OW','SQ','UN','UT'}
		res        = fread(fp,1,'ushort');
		tag.length = double(fread(fp,1,'uint'));
		% should check for length of FFFFFFFFH
		tag.le     = tag.le + 6;
	otherwise,
		tag.length = double(fread(fp,1,'ushort'));
		tag.le     = tag.le + 2;
	end;
else,
	tag.le =  8;
	tag.length = double(fread(fp,1,'uint'));
	% should check for length of FFFFFFFFH
end;
if isempty(tag.vr) | isempty(tag.length)
	tag = [];
	return;
end;
if tag.length==13,
	% disp(['Whichever manufacturer created "' fopen(fp) '" is taking the p***!']);
	% For some bizarre reason, known only to themselves, they confuse lengths of
	% 13 with lengths of 10.
	tag.length = 10;
end;
if rem(tag.length,2),
	warning(['Unknown odd numbered Value Length (' num2str(tag.length) ') in "' fopen(fp) '".']);
	tag = [];
end;
return;
%_______________________________________________________________________

%_______________________________________________________________________
function dict = readdict
dict = load('spm_dicom_dict.mat');
return;
%_______________________________________________________________________

%_______________________________________________________________________
function dict = readdict_txt
file = textread('spm_dicom_dict.txt','%s','delimiter','\n','whitespace','');
clear values
for i=1:length(file),
	words = strread(file{i},'%s','delimiter','\t');
	if length(words)>=5,
		grp = sscanf(words{1},'%x');
		ele = sscanf(words{2},'%x');
		if ~isempty(grp) & ~isempty(ele),
			group(i)   = grp;
			element(i) = ele;
			vr         = {};
			for j=1:length(words{4})/2,
				vr{j}  = words{4}(2*(j-1)+1:2*(j-1)+2);
			end;
			name       = words{3};
			msk        = find(~(name>='a' & name<='z') & ~(name>='A' & name<='Z') &...
			                  ~(name>='0' & name<='9') & ~(name=='_'));
			name(msk)  = '';
			values(i)  = struct('name',name,'vr',{vr},'vm',words{5});
		end;
	end;
end;

tags = sparse(group+1,element+1,1:length(group));
dict = struct('values',values,'tags',tags);
return;
%_______________________________________________________________________

%_______________________________________________________________________
function t = decode_csa(fp,lim)
% Decode shadow information (0029,1010) and (0029,1020)
[fname,perm,fmt] = fopen(fp);
pos = ftell(fp);
if strcmp(fmt,'ieee-be'),
        fclose(fp);
        fp  = fopen(fname,perm,'ieee-le');
        fseek(fp,pos,'bof');
        flg = 'b';
end;

c   = fread(fp,4,'char');
fseek(fp,pos,'bof');

if all(c'==[83 86 49 48]), % "SV10"
	t = decode_csa2(fp,lim);
else,
	t = decode_csa1(fp,lim);
end;

if strcmp(fmt,'ieee-le'),
	fclose(fp);
	fp  = fopen(fname,perm,fmt);
end;
fseek(fp,pos+lim,'bof');
return;
%_______________________________________________________________________

%_______________________________________________________________________
function t = decode_csa1(fp,lim)
n   = fread(fp,1,'uint32');
if n>128 | n < 0,
	fseek(fp,lim-4,'cof');
	t = struct('junk','Don''t know how to read this damned file format');
	return;
end;
xx  = fread(fp,1,'uint32')'; % "M" or 77 for some reason
tot = 2*4;
for i=1:n,
	t(i).name    = fread(fp,64,'char')';
	msk          = find(~t(i).name)-1;
	if ~isempty(msk),
		t(i).name    = char(t(i).name(1:msk(1)));
	else,
		t(i).name    = char(t(i).name);
	end;
	t(i).vm      = fread(fp,1,'int32')';
	t(i).vr      = fread(fp,4,'char')';
	t(i).vr      = char(t(i).vr(1:3));
	t(i).syngodt = fread(fp,1,'int32')';
	t(i).nitems  = fread(fp,1,'int32')';
	t(i).xx      = fread(fp,1,'int32')'; % 77 or 205
	tot          = tot + 64+4+4+4+4+4;
	for j=1:t(i).nitems
		% This bit is just wierd
		t(i).item(j).xx  = fread(fp,4,'int32')'; % [x x 77 x]
		len              = t(i).item(j).xx(1)-t(1).nitems;
		if len<0 | len+tot+4*4>lim,
			t(i).item(j).val = '';
			tot              = tot + 4*4;
			break;
		end;
		t(i).item(j).val = char(fread(fp,len,'char'))';
		fread(fp,rem(4-rem(len,4),4),'char')';
		tot              = tot + 4*4+len+rem(4-rem(len,4),4);
	end;
end;
return;
%_______________________________________________________________________

%_______________________________________________________________________
function t = decode_csa2(fp,lim)
c   = fread(fp,4,'char');
n   = fread(fp,4,'char');
n   = fread(fp,1,'uint32');
if n>128 | n < 0,
	fseek(fp,lim-4,'cof');
	t = struct('junk','Don''t know how to read this damned file format');
	return;
end;
xx  = fread(fp,1,'uint32')'; % "M" or 77 for some reason
for i=1:n,
	t(i).name    = fread(fp,64,'char')';
	msk          = find(~t(i).name)-1;
	if ~isempty(msk),
		t(i).name    = char(t(i).name(1:msk(1)));
	else,
		t(i).name    = char(t(i).name);
	end;
	t(i).vm      = fread(fp,1,'int32')';
	t(i).vr      = fread(fp,4,'char')';
	t(i).vr      = char(t(i).vr(1:3));
	t(i).syngodt = fread(fp,1,'int32')';
	t(i).nitems  = fread(fp,1,'int32')';
	t(i).xx      = fread(fp,1,'int32')'; % 77 or 205
	for j=1:t(i).nitems
		t(i).item(j).xx  = fread(fp,4,'int32')'; % [x x 77 x]
		len              = t(i).item(j).xx(2);
		t(i).item(j).val = char(fread(fp,len,'char'))';
		fread(fp,rem(4-rem(len,4),4),'char');
	end;
end;
return;
%_______________________________________________________________________
