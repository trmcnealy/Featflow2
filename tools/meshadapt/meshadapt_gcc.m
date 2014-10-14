function [methodinfo,structs,enuminfo,ThunkLibName]=meshadapt_gcc
%MESHADAPT_GCC Create structures to define interfaces found in 'meshadapt_gcc'.

%This function was generated by loadlibrary.m parser version  on Mon Sep 22 16:49:41 2014
%perl options:'meshadapt_gcc.i -outfile=meshadapt_gcc.m -thunkfile=meshadapt_thunk_glnxa64.c -header=meshadapt_gcc.h types'
ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
structs=[];enuminfo=[];fcnNum=1;
fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival,'thunkname', ival);
MfilePath=fileparts(mfilename('fullpath'));
ThunkLibName=fullfile(MfilePath,['meshadapt_thunk_' lower(computer)]);
% void __fsystem_MOD_sys_init_simple (); 
fcns.thunkname{fcnNum}='voidThunk';fcns.name{fcnNum}='__fsystem_MOD_sys_init_simple'; fcns.alias{fcnNum}='sys_init_simple'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% void __genoutput_MOD_output_init_simple (); 
fcns.thunkname{fcnNum}='voidThunk';fcns.name{fcnNum}='__genoutput_MOD_output_init_simple'; fcns.alias{fcnNum}='output_init_simple'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% void __storage_MOD_storage_done ( void *); 
fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='__storage_MOD_storage_done'; fcns.alias{fcnNum}='storage_done'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
% void __storage_MOD_storage_init ( int *, int *, void *); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='__storage_MOD_storage_init'; fcns.alias{fcnNum}='storage_init'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'int32Ptr', 'int32Ptr', 'voidPtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_alloc ( struct t_meshAdapt **); 
fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_alloc'; fcns.alias{fcnNum}='madapt_alloc'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtrPtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_dealloc ( struct t_meshAdapt **); 
fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_dealloc'; fcns.alias{fcnNum}='madapt_dealloc'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtrPtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_init ( struct t_meshAdapt *, int *, char *, int ); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrcstringint32Thunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_init'; fcns.alias{fcnNum}='madapt_init'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'int32Ptr', 'cstring', 'int32'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_step_fromfile ( struct t_meshAdapt *, char *, int *, double *, double *, int ); 
fcns.thunkname{fcnNum}='voidvoidPtrcstringvoidPtrvoidPtrvoidPtrint32Thunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_step_fromfile'; fcns.alias{fcnNum}='madapt_step_fromfile'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'cstring', 'int32Ptr', 'doublePtr', 'doublePtr', 'int32'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_step_dble2 ( struct t_meshAdapt *, int *, double *, int *, double *, double *); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_step_dble2'; fcns.alias{fcnNum}='madapt_step_dble2'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'int32Ptr', 'doublePtr', 'int32Ptr', 'doublePtr', 'doublePtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_done ( struct t_meshAdapt *); 
fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_done'; fcns.alias{fcnNum}='madapt_done'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr'};fcnNum=fcnNum+1;
% int __meshadaptbase_MOD_madapt_getnel ( struct t_meshAdapt *); 
fcns.thunkname{fcnNum}='int32voidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getnel'; fcns.alias{fcnNum}='madapt_getnel'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'t_meshAdaptPtr'};fcnNum=fcnNum+1;
% int __meshadaptbase_MOD_madapt_getnvt ( struct t_meshAdapt *); 
fcns.thunkname{fcnNum}='int32voidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getnvt'; fcns.alias{fcnNum}='madapt_getnvt'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'t_meshAdaptPtr'};fcnNum=fcnNum+1;
% int __meshadaptbase_MOD_madapt_getndim ( struct t_meshAdapt *); 
fcns.thunkname{fcnNum}='int32voidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getndim'; fcns.alias{fcnNum}='madapt_getndim'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'t_meshAdaptPtr'};fcnNum=fcnNum+1;
% int __meshadaptbase_MOD_madapt_getnnve ( struct t_meshAdapt *); 
fcns.thunkname{fcnNum}='int32voidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getnnve'; fcns.alias{fcnNum}='madapt_getnnve'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'t_meshAdaptPtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_getvertexcoords ( struct t_meshAdapt *, double *); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getvertexcoords'; fcns.alias{fcnNum}='madapt_getvertexcoords'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'doublePtr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_getverticesatelement ( struct t_meshAdapt *, int *); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getverticesatelement'; fcns.alias{fcnNum}='madapt_getverticesatelement'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'int32Ptr'};fcnNum=fcnNum+1;
% void __meshadaptbase_MOD_madapt_getneighboursatelement ( struct t_meshAdapt *, int *); 
fcns.thunkname{fcnNum}='voidvoidPtrvoidPtrThunk';fcns.name{fcnNum}='__meshadaptbase_MOD_madapt_getneighboursatelement'; fcns.alias{fcnNum}='madapt_getneighboursatelement'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'t_meshAdaptPtr', 'int32Ptr'};fcnNum=fcnNum+1;
structs.t_fparserComponent.members=struct('ibytecodeSize', 'int32', 'iimmedSize', 'int32', 'istackSize', 'int32', 'istackPtr', 'int32', 'buseDegreeConversion', 'int', 'bisVectorizable', 'int', 'IbyteCode', 'int16Ptr', 'Dimmed', 'doublePtr');
structs.t_fparser.members=struct('Rcomp', 't_fparserComponentPtr', 'ScompName', 'cstring', 'ncomp', 'int32', 'nncomp', 'int32');
structs.t_boundary.members=struct('iboundarycount_g', 'int32', 'iboundarycount', 'int32', 'h_DmaxPar', 'int32', 'h_IsegCount', 'int32', 'h_Idbldatavec_handles', 'int32', 'h_Iintdatavec_handles', 'int32', 'h_Iintdatavec_fparser', 'int32', 'p_rfparser', 't_fparserPtr');
structs.t_quadtreeDP.members=struct('NFREE', 'int32', 'NDATA', 'int32', 'NVT', 'int32', 'NNVT', 'int32', 'NNODE', 'int32', 'NNNODE', 'int32', 'NRESIZE', 'int32', 'dfactor', 'double', 'h_Data', 'int32', 'h_BdBox', 'int32', 'p_Data', 'doublePtr', 'p_BdBox', 'doublePtr', 'h_Knode', 'int32', 'p_Knode', 'int32Ptr');
structs.t_octreeDP.members=struct('NFREE', 'int32', 'NDATA', 'int32', 'NVT', 'int32', 'NNVT', 'int32', 'NNODE', 'int32', 'NNNODE', 'int32', 'NRESIZE', 'int32', 'dfactor', 'double', 'h_Data', 'int32', 'h_BdBox', 'int32', 'p_Data', 'doublePtr', 'p_BdBox', 'doublePtr', 'h_Knode', 'int32', 'p_Knode', 'int32Ptr');
structs.t_mapInt_DP.members=struct('NA', 'int32', 'NNA', 'int32', 'NNA0', 'int32', 'nresize', 'int32', 'dfactor', 'double', 'h_Key', 'int32', 'p_Key', 'int32Ptr', 'p_Kbal', 'int32Ptr', 'p_Kparent', 'int32Ptr', 'p_Kchild', 'int32Ptr', 'isizeData', 'int32', 'h_Data', 'int32', 'p_Data', 'doublePtr');
structs.t_arraylistInt.members=struct('ntable', 'int32', 'nntable', 'int32', 'nntable0', 'int32', 'NA', 'int32', 'NNA', 'int32', 'NNA0', 'int32', 'nresize', 'int32', 'dfactor', 'double', 'h_Ktable', 'int32', 'p_Ktable', 'int32Ptr', 'h_Knext', 'int32', 'h_Kprev', 'int32', 'p_Knext', 'int32Ptr', 'p_Kprev', 'int32Ptr', 'h_Key', 'int32', 'p_Key', 'int32Ptr');
structs.t_hadapt.members=struct('iSpec', 'int32', 'iduplicationFlag', 'int32', 'iadaptationStrategy', 'int32', 'nsubdividemax', 'int32', 'nRefinementSteps', 'int32', 'nCoarseningSteps', 'int32', 'nSmoothingSteps', 'int32', 'drefinementTolerance', 'int32', 'dcoarseningTolerance', 'int32', 'ndim', 'int32', 'NVT0', 'int32', 'NVT', 'int32', 'increaseNVT', 'int32', 'NVBD0', 'int32', 'NVBD', 'int32', 'NBCT', 'int32', 'NEL0', 'int32', 'NEL', 'int32', 'NELMAX', 'int32', 'nGreenElements', 'int32', 'InelOfType', 'int32#8', 'InelOfType0', 'int32#8', 'h_Imarker', 'int32', 'h_IvertexAge', 'int32', 'p_IvertexAge', 'int32Ptr', 'h_InodalProperty', 'int32', 'p_InodalProperty', 'int32Ptr', 'h_IverticesAtElement', 'int32', 'p_IverticesAtElement', 'int32Ptr', 'h_IneighboursAtElement', 'int32', 'p_IneighboursAtElement', 'int32Ptr', 'h_ImidneighboursAtElement', 'int32', 'p_ImidneighboursAtElement', 'int32Ptr', 'h_DvertexCoords1D', 'int32', 'rVertexCoordinates2D', 't_quadtreeDP', 'rVertexCoordinates3D', 't_octreeDP', 'rBoundary', 't_mapInt_DPPtr', 'rElementsAtVertex', 't_arraylistInt');
structs.t_triangulation.members=struct('iduplicationFlag', 'int32', 'ndim', 'int32', 'NVT', 'int32', 'NMT', 'int32', 'NAT', 'int32', 'NEL', 'int32', 'NBCT', 'int32', 'NblindBCT', 'int32', 'NVBD', 'int32', 'NABD', 'int32', 'NMBD', 'int32', 'NNVE', 'int32', 'NNEE', 'int32', 'NNAE', 'int32', 'NNVA', 'int32', 'NNelAtVertex', 'int32', 'NNelAtEdge', 'int32', 'InelOfType', 'int32#8', 'nverticesPerEdge', 'int32', 'nVerticesOnAllEdges', 'int32', 'nverticesInEachElement', 'int32', 'nverticesInAllElements', 'int32', 'nadditionalVertices', 'int32', 'DboundingBoxMin', 'double#3', 'DboundingBoxMax', 'double#3', 'h_DvertexCoords', 'int32', 'h_IverticesAtElement', 'int32', 'h_IedgesAtElement', 'int32', 'h_IneighboursAtElement', 'int32', 'h_IelementsAtEdge', 'int32', 'h_IverticesAtEdge', 'int32', 'h_InodalProperty', 'int32', 'h_ImacroNodalProperty', 'int32', 'h_DelementVolume', 'int32', 'h_IelementsAtVertexIdx', 'int32', 'h_IelementsAtVertex', 'int32', 'h_IrefinementPatchIdx', 'int32', 'h_IrefinementPatch', 'int32', 'h_IcoarseGridElement', 'int32', 'h_IboundaryCpIdx', 'int32', 'h_IverticesAtBoundary', 'int32', 'h_IboundaryCpEdgesIdx', 'int32', 'h_IedgesAtBoundary', 'int32', 'h_IboundaryCpFacesIdx', 'int32', 'h_IfacesAtBoundary', 'int32', 'h_IelementsAtBoundary', 'int32', 'h_DvertexParameterValue', 'int32', 'h_DedgeParameterValue', 'int32', 'h_IboundaryVertexPos', 'int32', 'h_IboundaryEdgePos', 'int32', 'h_DfreeVertexCoordinates', 'int32', 'h_IelementsAtEdgeIdx3D', 'int32', 'h_IelementsAtEdge3D', 'int32', 'h_IfacesAtEdgeIdx', 'int32', 'h_IfacesAtEdge', 'int32', 'h_IfacesAtVertexIdx', 'int32', 'h_IfacesAtVertex', 'int32', 'h_IfacesAtElement', 'int32', 'h_IverticesAtFace', 'int32', 'h_IelementsAtFace', 'int32', 'h_IedgesAtFace', 'int32', 'h_IedgesAtVertexIdx', 'int32', 'h_IedgesAtVertex', 'int32', 'h_ItwistIndex', 'int32');
structs.t_meshAdapt.members=struct('rboundary', 't_boundaryPtr', 'rtriangulation', 't_triangulation', 'rhadapt', 't_hadapt', 'nrefmax', 'int32', 'dreftol', 'double', 'dcrstol', 'double');
methodinfo=fcns;