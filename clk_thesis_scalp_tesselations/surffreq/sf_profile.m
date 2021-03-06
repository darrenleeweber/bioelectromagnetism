function [varargout] = sf_profile(command,varargin)
% SF_PROFILE	Profile command with specified arguments
%   	    	SF_PROFILE('command' [, arguments])

% Copyright (c) 1997 Clif Kussmaul. All rights reserved.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% action starts here

if nargin < 1 help sf_profile; return; end
    
profile(command)
if nargout > 1
    [varargout{1:nargout}] = feval(command,varargin{:});
else
    feval(command,varargin{:});
end
profile report, profile done
