function [dA, AUC, zH, zF, a, b] = getROC(DV, lambda, targ, resp)
% Compute sdt params for yes/no paradigm
%
% @Parameters:     	DV      real matrix, 1 column per criteroin location
%                   lambda	real row-vector, 1 element per criterion
%                   targ  	binary matrix, 1 column per criterion location
%                   resp    binary matrix, 1 column per criterion location
%
% @Returns:         dA      estimate of sensitivity
%                   AUC   	Area Under Curve (another sensitvity measure)
%                   H       z-score hit rate (adjusted if infinite)
%                   F       z-score false-alarm rate (adjusted if infinite)
%
% @Author:
%   Pete R Jones <petejonze@gmail.com>
%
% *********************************************************************

    % init storage
    n       = length(lambda);
    H       = nan(n,1); % hit rate
    F       = nan(n,1); % false-alarm rate

    % get response as criteiron is slide across
    if nargin < 4 || isempty(resp)
        resp = bsxfun(@gt, DV, lambda);
    end

    % get hits and false alarms (could be vectorized for speed)
    for i = 1:n
        [~,~,~,H(i),F(i)]	= getSDT(resp(:,i), targ);
    end
    zH = norminv(H);  % z-score hit rate
    zF = norminv(F);  % z-score false-alarm rate
        
    % Get slope and intercept of best line fit (n.b., curve should be
    % linear given z-transforms above (if internal noise is gaussian)
    stats       = regstats(zH, zF);
    a           = stats.beta(1);    % ROC intercept
    b           = stats.beta(2);    % ROC slope

    % n.b., error in both axes, so should technically use Total Least
    % Sqaures or something similar, but here the error so small as to make
    % this negligible. Nonetheless, let's do a little sanity check
    if stats.rsquare < .95
        warning('Excessive error in ROC fit(??)');
        % sanity check (uncomment for plot):
        % figure(); plot(zF,zH,'o', zF,a+b*zF,'r-');
    end

    % compute sensitivity param:
    Az	= normcdf(a/sqrt(1+b^2));
    dA	= sqrt(2) * norminv(Az);
    
    % compute Area Under Curve
    h   = flipud(H(:,1));
    f   = flipud(F(:,1));
    AUC = 0.5 * (1 + sum(h(1:end-1).*f(2:end) - ...
          h(2:end).*f(1:end-1)) + h(end) - f(end));

end