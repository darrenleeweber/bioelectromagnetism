function [p] = eeg_linfit(p)

% eeg_linfit - returns slope/intercept of linear fit
%
% USEAGE: [p] = eeg_linfit(p)
%
% p is the eeg_toolbox struct.  For this function, the fields
% required are:
%
%   p.volt.data - voltage data matrix (Npoints,Nelec)
%   p.volt.timeArray - voltage sample points (msec)
%
% Returns slope and intercept matrices (Npoints,Nelec)
% for linear fit of each electrode into fields of p:
%
%   p.volt.fitslope
%   p.volt.fitintercept
%
% The column vectors of slope/intercept hold constant 
% values.  So, the linear fit data can be generated by:
% 
% y = p.volt.fitslope .* p.volt.timeArray + p.volt.fitintercept;
% 
% Where necessary, the p.volt.timeArray is replicated
% across columns for each electrode to enable this calculation
% 

% $Revision: 1.1 $ $Date: 2004/11/12 01:32:33 $

% Licence:  GNU GPL, no implied or express warranties
% History:  07/00, Darren.Weber_at_radiology.ucsf.edu
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% volt.timeArray is essentially a column vector, but
% operations in the eeg_toolbox may replicate across N columns
time = p.volt.timeArray(:,1);

slope = zeros(1,size(p.volt.data,2));
intercept = slope;

for elec = 1:size(p.volt.data,2),
    
    y = polyfit(time,p.volt.data(:,elec),1);
    slope(1,elec) = y(1);
    intercept(1,elec) = y(2);
end

% make sure that volt.timeArray is same size as volt.data
if ~isequal(size(p.volt.timeArray),size(p.volt.data)),
    p.volt.timeArray = repmat(p.volt.timeArray(:,1),1,size(p.volt.data,2));
end

p.volt.fitslope = repmat(slope,size(p.volt.data,1),1);
p.volt.fitintercept = repmat(intercept,size(p.volt.data,1),1);

return
