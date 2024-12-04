
%% preparation
% According to your experimental parameters and certain file direction, Change these bellow.
clc;clear
warning('off');
wholepath='F:\mice_data\';%%%%change
codepath =fullfile(wholepath, 'fMRI_code');
cd(codepath);
addpath(genpath(codepath));
template = fullfile(wholepath,'\temp\mice_Template.nii');
templatmask= spm_read_vols(spm_vol(fullfile(wholepath,'\temp\mice_Template_mask.nii')));

Animal_path{01} = fullfile(wholepath,'20201231_100357_20201231_zyj_BF_chat_mouse01_1_1');
Animal_path{02} = fullfile(wholepath,'20210106_101855_20210106_zyj_BF_chat_mouse02_1_1');

Animal_EPI_type  = {'0.5s_duration';'2s_duration';};

Animal_EPI_folder{01} = {[10 11 12], [15 16 17]}; %
Animal_EPI_folder{02} = {[10 11 12],[15 16 17]}


Animal_T2RARE = {5,5};
Animal_B0map = {6,6};

%% tsfMRI
dur = [0.5,2]; % block analysis
OFFwait = 15;
interval=[15,19.5,10.5,12,13.5,19.5,12,13.5,19.5,10.5,13.5,10.5,12,16.5,10.5,16.5,18,16.5,16.5,15,18,15,19.5,15,18,12,13.5,18];%
onset1 = [cumsum([0 dur(1)*ones(1,numel(interval)-1)])+cumsum([OFFwait interval(1:end-1)])];
onset2 = [cumsum([0 dur(2)*ones(1,numel(interval)-1)])+cumsum([OFFwait interval(1:end-1)])];
ons=[onset1;onset2];

%1:Bruker2nifiti--2:slicetiming
%3:mask image---4:realiment---5:calculate VDM---6:Coregistration---7:normalize
%8:smooth---9:template mask---10:GLM


for number =[1 2]%
    path = Animal_path{number};
    EPI_folder = sort(spm_cat(Animal_EPI_folder{number}),'ascend');
    %     RARE = Animal_T2RARE{number};
    %     Fieldmap = Animal_B0map{number};
    spm('defaults', 'FMRI');
    set(spm('CreateIntWin','off'),'Visible','on');
    
    for flag_stage =[1:10]
        if flag_stage == 1
            %% Bruker2nifiti
            Bruker2nifti_multislice(path,RARE,'mouse');
            Bruker2nifti_multislice(path,Fieldmap,'mouse');
            Bruker2nifti_multislice(path,EPI_folder,'mouse');
        end
        
        if flag_stage == 2
            %% Slicetiming
            for kk = EPI_folder
                Segments = MY_search_bruker_method('Segments',kk,path);
                EPI_TR = MY_search_bruker_method('EPI_TR',kk,path)/1000*Segments;
                Nslice = MY_search_bruker_method('Nslice',kk,path);
                all_func = MY_find_images_in_all_scans(path,'Results',{kk},'^2dseq','.img',[1 Inf],'separate_cells');
                slicetiming_mlb = MY_get_default_slicetiming_batch_struct(all_func,Nslice,EPI_TR);
                disp('Start to process Slicetiming!')
                spm_jobman('run',slicetiming_mlb);
            end
        end
        
        if flag_stage == 3
            %% mask all EPI and RARE img
            cd([path 'Results']);
            EPI_mask = spm_read_vols(spm_vol('EPI_mask.nii'));
            T2_mask = spm_read_vols(spm_vol('T2_mask.nii'));
            Fieldmap_mask = spm_read_vols(spm_vol('Fieldmap_mask.nii'));
            MY_mask_images(path,EPI_folder,'T2dseq.nii.gz',EPI_mask,'ms2dseq.nii','EPI');
            MY_mask_images(path,RARE,'2dseq.nii',T2_mask,'T2_m.nii','T2');
            MY_mask_images(path,Fieldmap,'2dseq.nii',Fieldmap_mask,'Fieldmap.nii','Fieldmap');
        end
        
        if flag_stage == 4
            %% Realignment
            all_func = MY_find_images_in_all_scans(path,'Results',{EPI_folder(:)},'^ms2dseq','.nii',[1 Inf],'separate_cells');
            realign_mlb = MY_get_default_realign_batch_struct(all_func);
            F = spm_figure('GetWin');
            disp('Start to process realignment !')
            spm_jobman('run',realign_mlb);
            hgexport(figure(F), fullfile([path,'Results\'],strcat('realign')), hgexport('factorystyle'), 'Format', 'tiff');
            clear realign_mlb all_func;
        end
        
        if flag_stage == 5
            for kk = EPI_folder
                %% calculate VDM
                phasemap{1,1} = [path '\Results\FieldMap1\Fieldmap.nii,1'];
                magnitudemap{1,1} = [path '\Results\FieldMap2\Fieldmap.nii,1'];
                epi_first_frame{1,1} = [path '\Results\' num2str(kk) '\2dseq.nii,1'];
                EffectiveTE = MY_search_bruker_method('Effective_TE',Fieldmap,path);
                tert = MY_search_bruker_method('total_EPI_readout_time',kk,path);
                calculateVDM_mlb = MY_get_default_calculateVDM_batch_struct(phasemap, magnitudemap,epi_first_frame,EffectiveTE,tert);
                disp('Start to process calculateVDM!');
                F = spm_figure('GetWin');
                spm_jobman('run',calculateVDM_mlb);
                hgexport(figure(F), fullfile([path '\Results\' num2str(kk)], 'calculateVDM'), hgexport('factorystyle'), 'Format', 'tiff');
                %% apply VDM
                file_path = [path,'Results\',num2str(kk)];
                cd (file_path);
                all_func = MY_find_images_in_all_scans(path,'Results',{kk},'^rm2dseq','.nii',[1 Inf],'separate_cells');
                vdmfile_dir =  dir([path '\Results\FieldMap1\vdm*.nii']);
                vdmfile{1,1} = [path '\Results\FieldMap1\' vdmfile_dir.name ',1'];
                applyVDM_mlb = MY_get_default_applyVDM_batch_struct(all_func{:},vdmfile);
                disp('Start to process applyVDM!');
                spm_jobman('run',applyVDM_mlb);
            end
            clear phasemap magmap mean_epi  all_epi vdmfile calculateVDM_mlb applyVDM_mlb;
        end
        if flag_stage == 6
            %% Func2T2 Coregistration
            ref{1,1} = [path 'Results\' num2str(EPI_folder(1)) '\rms2dseq.nii,1'];
            source{1,1} = [path 'Results\T2\T2_m.nii,1'];
            Func2T2W_mlb = MY_get_default_coreg_batch_struct(ref, source, {''});
            disp('Start to process Func2T2W coregistration!');
            F = spm_figure('GetWin');
            spm_jobman('run',Func2T2W_mlb);
            hgexport(figure(F), fullfile([path 'Results\'], 'coreg'), hgexport('factorystyle'), 'Format', 'tiff');
            clear Func2T2W_mlb other ref source;
        end
        if flag_stage == 7
            %% T22Template coregistration
            ref{1,1} =template;%[path 'Results\Template_Mouse_38.nii'];
            source{1,1} = [path 'Results\T2\cT2_m.nii,1'];
            all_func = MY_find_images_in_all_scans(path,'Results',{EPI_folder(:)},'^rms2dseq','.nii',[1 Inf],'all_mixed');
            OldNormalize_mlb = MY_get_default_oldnormalize_batch_struct(ref, source, all_func);
            disp('Start to process OldNormalize!');
            F = spm_figure('GetWin');
            spm_jobman('run',OldNormalize_mlb);
            hgexport(figure(F), fullfile([path 'Results\'], strcat('oldnormalize')), hgexport('factorystyle'), 'Format', 'tiff');
            clear OldNormalize_mlb other ref source;
        end
        if flag_stage == 8
            %% smooth_space
            all_func = MY_find_images_in_all_scans(path,'Results',{EPI_folder(:)},'^nrms2dseq','.nii',[1 Inf],'all_mixed');
            Smooth_mlb = MY_get_default_smooth_batch_struct(all_func);
            disp('Start to process Smooth!');
            spm_jobman('run',Smooth_mlb);
            clear Smooth_mlb;
        end
        
        if  flag_stage== 9
            
            MY_mask_images(path,EPI_folder,'snrms2dseq.nii', templatmask,'snrms2dseq.nii','EPI');
        end
        
        if flag_stage == 10
            for idx =1:numel(Animal_EPI_type)
                protocol = Animal_EPI_type{idx};
                folder = Animal_EPI_folder{number}{idx};
                duration=dur(idx);
                onset=ons(idx,:);
                colorbar = [-5 -1.65 1.65 5];
                Reg_choices = {'rp';'rp"';'PCs'};
                
                result_1st = struct('weights',1,'slice',1:35,'template',template,'FDR_pvalue',0.05,'colorbar',colorbar);
                %                         % individual
                defined_1st = struct('Nscans','individual','filename','^snrms2dseq','duration',duration,'onset',onset);
                MY_task_state_statistics(path,'Results',{folder(:)},[1 Inf],Reg_choices,defined_1st,result_1st);
                %                         Allscans
                defined_1st = struct('Nscans','Allscans','filename','^snrms2dseq','duration',duration,'onset',onset);
                MY_task_state_statistics(path,'Results',{folder(:)},[1 Inf],Reg_choices,defined_1st,result_1st);
                
                % ---------- rename the animal-wise folder ----------
                cd([path '\Functions\tsfMRI']);
                if exist(['Allscans_',protocol],'dir');rmdir(['Allscans_',protocol]);end
                eval(['!rename,Allscans,Allscans_',protocol])
                % ---------- delete it after this protocol ----------
            end
        end
    end
end
