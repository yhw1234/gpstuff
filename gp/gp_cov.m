function [C, Cinv] = gp_cov(gp, x1, x2, predcf)
%GP_COV  Evaluate covariance matrix between two input vectors. 
%
%  Description
%    C = GPCOV(GP, TX, X, PREDCF) takes in Gaussian process GP and
%    two matrixes TX and X that contain input vectors to GP. 
%    Returns covariance matrix C. Every element ij of C contains
%    covariance between inputs i in TX and j in X. PREDCF is an
%    optional array specifying the indexes of covariance functions,
%    which are used for forming the matrix. If empty or not given,
%    the matrix is formed with all functions.

% Copyright (c) 2007-2010 Jarno Vanhatalo
% Copyright (c) 2010 Tuomas Nikoskinen

% This software is distributed under the GNU General Public 
% License (version 2 or later); please refer to the file 
% License.txt, included with the software, for details.

% Are gradient observations available; derivobs=1->yes, derivobs=0->no
Cinv=[];
if ~(isfield(gp,'derivobs') && gp.derivobs)
  ncf = length(gp.cf);

  C = sparse(0);
  if nargin < 4 || isempty(predcf)
    predcf = 1:ncf;
  end      
  for i=1:length(predcf)
    gpcf = gp.cf{predcf(i)};
    C = C + feval(gpcf.fh.cov, gpcf, x1, x2);
  end

else
  % Derivative observations
  [n,m]=size(x1);
  [n4,m4]=size(x2);
  gpcf = gp.cf{1};    % Grad obs implemented only to sexp currently
  
  if m==1
    Gset = feval(gpcf.fh.ginput4, gpcf, x1, x2);
    Kff = feval(gpcf.fh.cov, gpcf, x1, x2);
    Kdd = feval(gpcf.fh.ginput2, gpcf, x1, x2);

    Kdf=Gset{1};
    Kfd = -1.*Kdf; 
    C = [Kff Kfd; Kdf Kdd{1}];

    % Input dimension is >1
  else
    [n,m]=size(x1);
    [n2,m2]=size(x2);                  

    Kff = feval(gpcf.fh.cov, gpcf, x1, x2);
    Gset = feval(gpcf.fh.ginput4, gpcf, x1, x2);

    %Gather matrices from Gset (d k(x1,x2) /d x1)
    Kdf=cat(1,Gset{1:m});
    Kfd=cat(2,Gset{1:m});
    Kfd=-1*Kfd;

    % both x derivatives, same dimension (to diagonal blocks)
    D = feval(gpcf.fh.ginput2, gpcf, x1, x2);
    % both x derivatives, different dimension (non-diagonal blocks)
    Kdf2 = feval(gpcf.fh.ginput3, gpcf, x1 ,x2);

    % Now build up Kdd m*n x m*n2 matrix, which contains all the
    % both partial derivative" -matrices

    % Add the diagonal matrices
    Kdd=blkdiag(D{1:m});
    % Add the non-diagonal matrices to Kdd
    ii3=0;
    for j=0:m-2
      for i=1+j:m-1
        ii3=ii3+1;
        Kdd(i*n+1:(i+1)*n,j*n2+1:j*n2+n2) = Kdf2{ii3};
        Kdd(j*n+1:j*n+n,i*n2+1:(i+1)*n2) = Kdf2{ii3};
      end
    end
    
    % Gather all the matrices into one final matrix K which is the 
    % training covariance matrix
    C = [Kff Kfd; Kdf Kdd];   
    
    % Add jitter if the inputs are equal
    n1 = size(x1,1);
    n2 = size(x2,1);
    if n1 == n2  && max(max(abs(x1-x2))) == 0
      if isfield(gp, 'jitterSigma2') && ~isempty(gp.jitterSigma2)
        n = length(C);
        C(1:n+1:n^2) = C(1:n+1:n^2) + gp.jitterSigma2;
      end
    end

    
  end       
end
