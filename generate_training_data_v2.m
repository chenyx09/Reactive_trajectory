%% generate training data
if exist('data.mat','file')==2&&0
    load data
    i=1;
    d = zeros(M,1);
    while i<=size(positive_data,1)
        i
        traj1=positive_data(i,end-2*m:end-1);
        for j=1:M
            d(j)=scaled_inf_norm(traj1,traj_base_kept(j,:));
        end
        [min_d,idx]=min(d);
        if min_d<=delta
            positive_data(i,end) = idx;
            i=i+1;
        else
            [cover_set,cover_score] = double_traj_cover(traj_base_kept,traj1,delta);
            [min_score,idx]=min(cover_score);
            if min_score<delta
                positive_data(i,:) = [positive_data(i,1:end-2*m-1) traj_base_kept(cover_set(idx,1),:) cover_set(idx,1)];
                positive_data = [positive_data;positive_data(i,1:end-2*m-1) traj_base_kept(cover_set(idx,2),:) cover_set(idx,2)];
                i=i+1;
            else
                unclassified_set = positive_data(i,1:end-1);
                positive_data(i,:)=[];
            end
        end
    end
else
%     generate_traj_bases;
    opts = detectImportOptions('Next_Generation_Simulation__NGSIM__Vehicle_Trajectories_and_Supporting_Data-1.csv');
    TT = 3;
    Ts = 0.1;
    Ts1 = 0.5;
    t_traj = 0:Ts1:TT;
    positive_data=[];
    traj_pool=[];
    unclassified_set=[];
    x_diff = [];
    cc =0;
    for part=1:11
        
        data=readtable(['Next_Generation_Simulation__NGSIM__Vehicle_Trajectories_and_Supporting_Data-',num2str(part),'.csv'],opts);
        data = data(contains(data.Location,'us-101'),:);
        if ~isempty(data)
            data = sortrows(data,'Global_Time');
            
            if ~exist('Bez_matr','var')
                bezier_regressor;
            end
            
            [a,b]=hist(data.Global_Time,unique(data.Global_Time));
            c=sortrows([a' b],1,'descend');
            T_min = min(b);
            T_max = max(b);
            processed_frames=[];
            affordance_set = {};
            counter = 0;
            
            M = size(traj_base,1);
            d = zeros(M,1);
            
            for n=1:size(c,1)
                
                if c(n,1)<20
                    break
                end
                t0 = c(n,2);
                if n<=5||min(abs(t0-c(1:n-1,2)))>8000
                    %         n
                    t_min = c(n,2)-TT*1000;
                    t_max = c(n,2)+TT*1000;
                    
                    if t_min>T_min && t_max<T_max
                        [veh_traj_set,frames]=data_interpolation(data,t_min,t_max,TT);
                        t_set = zeros(length(frames),1);
                        for i=1:length(frames)
                            t_set(i)=frames{i}.Global_Time(1);
                        end
                        for i=1:length(veh_traj_set)
                            if veh_traj_set(i).t(2)>TT*1000
                                t1 = veh_traj_set(i).t(1);
                                t_sample = t1+(0:Ts1:TT)*1000;
                                frame_idx = find(t_set==t1);
                                if ~isempty(frame_idx)
                                    frame1 = frames{frame_idx};
                                    idx = find(processed_frames==frame1.Global_Time(1));
                                    if isempty(idx)
                                        processed_frames = [processed_frames frame1.Global_Time(1)];
                                        affordance_set{counter+1} = calc_affordance_new(frame1);
                                        frame_affordance = affordance_set{counter+1};
                                        counter = counter+1;
                                    else
                                        frame_affordance = affordance_set{idx};
                                    end
                                    
                                    tt = t1 + (0:100:veh_traj_set(i).t(2));
                                    affordance = table2array(frame_affordance(frame_affordance.Vehicle_ID==veh_traj_set(i).Vehicle_ID,:));
                                    if isempty(affordance)
                                        disp('')
                                    else
                                        x_traj = interp1(tt,veh_traj_set(i).x_traj,t_sample);
                                        y_traj = interp1(tt,veh_traj_set(i).y_traj,t_sample);
                                        v_traj = interp1(tt,veh_traj_set(i).v_traj,t_sample);
                                        x_traj = x_traj-x_traj(1);
                                        y_traj = y_traj-y_traj(1);
                                        y_nom = veh_traj_set(i).v_traj(1)*(0:Ts1:TT);
                                        delta_y = y_traj - y_nom;
                                        
                                        traj1 = [delta_y x_traj];
                                        for j=1:M
                                            d(j)=scaled_inf_norm(traj1,traj_base(j,:));
                                        end
                                        [min_d,idx]=min(d);
                                        if min_d<=delta
                                            positive_data = [positive_data;affordance traj1 idx];
                                            cc=cc+1
                                        else
                                            [cover_set,cover_score] = double_traj_cover(traj_base,traj1,delta);
                                            [min_score,idx]=min(cover_score);
                                            if min_score<1.3*delta
                                                positive_data = [positive_data;affordance traj_base(cover_set(idx,1),:) cover_set(idx,1)];
                                                positive_data = [positive_data;affordance traj_base(cover_set(idx,2),:) cover_set(idx,2)];
                                                cc = cc+2
                                            else
                                                %                 traj_pool = [traj_pool;traj1];
                                                unclassified_set = [unclassified_set;affordance traj1];
                                                disp(['unclassified sample size =',num2str(size(unclassified_set,1))])
                                            end
                                            %                 M = M+1
                                            %                 training_data = [training_data;dp.affordance1 dp.affordance2 dp.affordance3 M];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    %% get rid of the underrepresented bases
    threshold = 10;
    [a,b] = hist(positive_data(:,end),1:M);
    under_rep_base = find(a<threshold);
    kept_base = find(a>=threshold);
    traj_base_kept = traj_base(kept_base,:);
    d = zeros(length(kept_base),1);
    i=1;
    while i<=size(positive_data,1)
        idx = positive_data(i,end);
        if ismember(idx,kept_base)
            positive_data(i,end) = find(kept_base==idx);
            i=i+1;
        else
            for j=1:size(traj_base_kept,1)
                d(j)=scaled_inf_norm(positive_data(i,end-2*m:end-1),traj_base_kept(j,:));
            end
            [min_d,min_idx]=min(d);
            if min_d<=delta
                positive_data(i,end) = min_idx;
                i=i+1;
            else
                [cover_set,cover_score] = double_traj_cover(traj_base_kept,positive_data(i,end-2*m:end-1),delta);
                [min_score,min_idx]=min(cover_score);
                if min_score<1.3*delta
                    positive_data(i,end-2*m:end) = [traj_base_kept(cover_set(min_idx,1),:) cover_set(min_idx,1)];
                    positive_data = [positive_data;positive_data(i,1:end-2*m-1) traj_base_kept(cover_set(min_idx,2),:) cover_set(min_idx,2)];
                    i=i+1;
                else
                    %                 traj_pool = [traj_pool;traj1];
                    positive_data(i,:)=[];
                    unclassified_set = [unclassified_set;positive_data(i,1:end-1)];
                end
            end
        end
        
    end
    %% handle the unclassified set
    i=1;
    while i<=size(unclassified_set,1)
        size(unclassified_set,1)
        for j=1:size(traj_base_kept,1)
            d(j)=scaled_inf_norm(unclassified_set(i,end-2*m+1:end),traj_base_kept(j,:));
        end
        [min_d,idx]=min(d);
        if min_d<=delta
            positive_data = [positive_data;unclassified_set(i,1:end) idx];
            unclassified_set(i,:)=[];
        else
            
            [cover_set,cover_score] = double_traj_cover(traj_base_kept,unclassified_set(i,end-2*m+1:end),delta);
            [min_score,idx]=min(cover_score);
            if min_score<1.3*delta
                positive_data = [positive_data;unclassified_set(i,1:end) cover_set(idx,1)];
                positive_data = [positive_data;unclassified_set(i,1:end) cover_set(idx,2)];
            else
                traj_base_kept = [traj_base_kept;unclassified_set(i,end-2*m+1:end)];
                positive_data = [positive_data;unclassified_set(i,1:end) size(traj_base_kept,1)];
                unclassified_set(i,:)=[];
            end
        end
    end
end
traj_base = traj_base_kept;
positive_data_orig = positive_data;











%% rule out conflicting positive data
M = size(traj_base_kept,1);
[a,b] = hist(positive_data(:,end),1:M);
% N_n = round(size(positive_data,1)*0.2);
negative_data = [];
i=1;
counter = 0;
while i<=size(positive_data,1)
    TTC = check_collision_v2(positive_data(i,1:28),traj_base(positive_data(i,43),:),Ts1,1.5);
    if TTC<inf
        positive_data(i,:)=[];
        counter= counter+1
    else
        i=i+1;
    end
end

for i=1:M
    positive_data_cell{i}=positive_data(positive_data(:,end)==i,:);
end
%% generate negative data
N_p = size(positive_data,1);
ideal_size = max(10000,a*0.8);
idx = randsample(1:N_p,N_p);
counter = 0;
for i=1:M
    negative_data_cell{i}=[];
end
for i=1:length(idx)
    for j=1:M
        if size(negative_data_cell{j},1)<3*ideal_size(j)
            TTC = check_collision_v2(positive_data(i,1:28),traj_base(j,:),Ts1,1.5);
            if TTC<inf
                negative_data_cell{j} = [negative_data_cell{j}; positive_data(idx(i),1:28) TTC];
                counter = counter +1
            end
        end
    end
end
for i=1:M
    negative_data_cell{i} = sortrows(negative_data_cell{i},29,'ascend');
end
% for i=1:M
%     if size(negative_data_cell{i},1)>ideal_size(i)
%         negative_data_cell{i}=sortrows(negative_data_cell{i},46,'ascend');
%         negative_data_cell{i} = negative_data_cell{i}(1:ideal_size(i),:);
%     end
% end
%% generate output flags
N_p = size(positive_data,1);
% output = zeros(N_p,M);
for i=1:size(positive_data)
    i
    for j=1:M
        if j==positive_data(i,end)
            output(i,j)=1;
        else
            TTC = check_collision_v2(positive_data(i,1:28),traj_base(j,:),Ts1,1.5);
            if TTC<inf
                output(i,j)=-1;
            end
        end
    end
end

%% Nonlinear features
%'v_Vel', 'dis2cen', 'fwd_dis', 'fwd_vel', 'left_front_Y','left_front_X','left_front_vel', 'left_rear_Y',
%'left_rear_X', 'left_rear_vel', 'right_front_Y', 'right_front_X', 'right_front_vel','right_rear_Y', 'right_rear_X',
%'right_rear_vel','left_front_L','left_rear_L','right_front_L','right_rear_L','L'
x_norm = max(abs(positive_data(:,[2:5,8:19,24:28])));
for i =1:M
    n_p(i) = size(positive_data_cell{i},1);
    xx = positive_data_cell{i}(:,[2:5,8:19,24:28]);
    phi_positive{i}=[ones(n_p(i),1) xx./x_norm tanh(3*xx./x_norm) (xx./x_norm).^2 ...
        min(xx(:,[5,8])./x_norm([5,8]),[],2) min(xx(:,[11,14])./x_norm([11,14]),[],2)];
    
    n_n(i) = size(negative_data_cell{i},1);
    xx = negative_data_cell{i}(:,[2:5,8:19,24:28]);
    phi_negative{i}=[ones(n_n(i),1) xx./x_norm tanh(3*xx./x_norm) (xx./x_norm).^2 ...
        min(xx(:,[5,8])./x_norm([5,8]),[],2) min(xx(:,[11,14])./x_norm([11,14]),[],2)];
end

% N_p = size(positive_data,1);
% h = mss_asd(12,2);
% 
% Fh = size(h,1);
% F = Fh+33;
% x_norm = max(abs(positive_data(:,[2,3,4,6,7,9,10,11,12,14,15])));
% for i=1:M
%     i
%     phi_positive{i} = [];
%     phi_negative{i} = [];
%     xx=[positive_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15]) ones(size(positive_data_cell{i},1),1)]./[x_norm 1];
%     for j=1:Fh
%         counter=1;
%         vec=ones(size(positive_data_cell{i},1),3);
%         for k=1:size(h,2)
%             if h(j,k)==1
%                 vec(:,counter)=xx(:,k);
%                 counter = counter+1;
%             elseif h(j,k)==2
%                 vec(:,counter)=xx(:,k).^2;
%                 counter = counter+1;
%             elseif h(j,k)==2
%                 vec(:,counter)=xx(:,k).^3;
%                 counter = counter+1;
%             end
%         end
%         phi_positive{i}(:,j)=vec(:,1).*vec(:,2).*vec(:,3);
%     end
%     phi_positive{i}=[phi_positive{i} tanh(3*positive_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm) ...
%         exp(-(positive_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm).^2)  positive_data_cell{i}(:,[2,3,4,6,7,9,10,11,12,14,15])./x_norm];
%     
%     xx=[negative_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15]) ones(size(negative_data_cell{i},1),1)]./[x_norm 1];
%     for j=1:Fh
%         counter=1;
%         vec=ones(size(negative_data_cell{i},1),3);
%         for k=1:size(h,2)
%             if h(j,k)==1
%                 vec(:,counter)=xx(:,k);
%                 counter = counter+1;
%             elseif h(j,k)==2
%                 vec(:,counter)=xx(:,k).^2;
%                 counter = counter+1;
%             elseif h(j,k)==2
%                 vec(:,counter)=xx(:,k).^3;
%                 counter = counter+1;
%             end
%         end
%         phi_negative{i}(:,j)=vec(:,1).*vec(:,2).*vec(:,3);
%     end
%     phi_negative{i}=[phi_negative{i} tanh(3*negative_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm) ...
%         exp(-(negative_data_cell{i}(:,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm).^2)  negative_data_cell{i}(:,[2,3,4,6,7,9,10,11,12,14,15])./x_norm];
    
    %     for j=1:size(positive_data_cell{i},1)
    %         xx=[positive_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15]) 1]./[x_norm 1];
    %         entry=zeros(1,Fh);
    %         for k=1:size(h,1)
    %             entry(k)=prod(xx.^h(k,:));
    %         end
    % %         entry(k+1:k+11)=positive_data_cell{i}(j,[2,3,4,6,7,9,10,11,12,14,15])./x_norm;
    %         phi_positive{i}=[phi_positive{i};[entry tanh(3*positive_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm)...
    %           exp(-(positive_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm).^2)  positive_data_cell{i}(j,[2,3,4,6,7,9,10,11,12,14,15])./x_norm]];
    %     end
    %     for j=1:size(negative_data_cell{i},1)
    %         xx=[negative_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15]) 1]./[x_norm 1];
    %         entry=zeros(1,Fh);
    %         for k=1:size(h,1)
    %             entry(k)=prod(xx.^h(k,:));
    %         end
    % %         entry(k+1:k+11)=negative_data_cell{i}(j,[2,3,4,6,7,9,10,11,12,14,15])./x_norm;
    %         phi_negative{i}=[phi_negative{i};[entry tanh(3*negative_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm)...
    %             exp(-(negative_data_cell{i}(j,30+[2,3,4,6,7,9,10,11,12,14,15])./x_norm).^2) negative_data_cell{i}(j,[2,3,4,6,7,9,10,11,12,14,15])./x_norm]];
    %     end
% end


%%



%% draw example trajectory
% idx = [315,4218,1033,877,3767];
% figure(1)
% clf
% hold on
% % v0 = traj_pool(idx,2*m+1);
% for n = 1:length(idx)
%
% v0 = 15;
% y_traj = traj_pool(idx(n),1:m)+v0*(0:Ts1:TT);
% x_traj = traj_pool(idx(n),m+1:2*m);
%
% for i = 1:m
%
%     ellipse(sqrt(delta)/y_scaling(i),sqrt(delta)/x_scaling(i),0,y_traj(i),x_traj(i),'r');
% end
%
% axis equal
%
% end
