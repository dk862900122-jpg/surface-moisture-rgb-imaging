clc;
clear;
close all;


%% =====================================================
% Pore Evolution Deterioration Index (PEDI)
%
% PEDI = 0.5P + 0.3N + 0.2C
%
% P : pore area ratio
% N : pore density
% C : pore connectivity
%
% =====================================================



%% ===========================
% 输入图片
% ===========================

files={
    'soil1.jpg'
    'soil2.jpg'
    'soil3.jpg'
    'soil4.jpg'
};


Nimg=length(files);



%% ===========================
% 初始化
% ===========================


P=zeros(Nimg,1);

N=zeros(Nimg,1);

C=zeros(Nimg,1);

MeanPore=zeros(Nimg,1);




%% =====================================================
% 图像处理
% =====================================================


for i=1:Nimg


    img=imread(files{i});



    if size(img,3)==3

        gray=rgb2gray(img);

    else

        gray=img;

    end



    gray=im2double(gray);





    %% -----------------------------------------
    % 1. 局部背景校正
    % ------------------------------------------


    background=imgaussfilt(gray,30);


    diffImg=background-gray;



    diffImg=(diffImg-min(diffImg(:)))...
        /(max(diffImg(:))-min(diffImg(:))+eps);





    %% -----------------------------------------
    % 2. 孔洞识别
    % ------------------------------------------


    mu=mean(diffImg(:));

    sigma=std(diffImg(:));


    k=1.2;



    bw=diffImg>mu+k*sigma;



    % 删除噪声

    bw=bwareaopen(bw,80);



    % 孔洞连接

    bw=imclose(bw,...
        strel('disk',4));



    % 填充

    bw=imfill(bw,'holes');






    %% -----------------------------------------
    % 3. P 孔洞面积率
    %
    % P=Ap/A
    % ------------------------------------------


    P(i)=sum(bw(:))/numel(bw);







    %% -----------------------------------------
    % 4. N 孔洞密度
    %
    % N=Np/A
    % ------------------------------------------


    CC=bwconncomp(bw);


    poreNum=CC.NumObjects;


    N(i)=poreNum/numel(bw);







    %% -----------------------------------------
    % 5. C 孔洞连通性
    %
    % 最大孔洞面积/总孔洞面积
    % ------------------------------------------


    stats=regionprops(bw,...
        'Area');


    if isempty(stats)

        C(i)=0;

        MeanPore(i)=0;


    else


        area=[stats.Area];


        C(i)=max(area)/sum(area);


        MeanPore(i)=mean(area);



    end







    %% -----------------------------------------
    % 显示
    % ------------------------------------------


    figure


    subplot(1,3,1)

    imshow(gray)

    title(['Original ',num2str(i)])



    subplot(1,3,2)

    imshow(diffImg,[])

    title('Local difference')



    subplot(1,3,3)

    imshow(bw)

    title('Detected pores')



end






%% =====================================================
% 归一化
% =====================================================


Pn=normalization(P);

Nn=normalization(N);

Cn=normalization(C);





%% =====================================================
% PEDI计算
% =====================================================


PEDI=...
    0.5*Pn+...
    0.3*Nn+...
    0.2*Cn;



% 再归一化

PEDI=normalization(PEDI);







%% =====================================================
% 输出结果
% =====================================================


fprintf('\n==============================================================\n')

fprintf('Image        P        N        C        PEDI\n')

fprintf('==============================================================\n')



for i=1:Nimg


    fprintf('%s   %.5f   %.5f   %.5f   %.5f\n',...
        files{i},...
        P(i),...
        N(i),...
        C(i),...
        PEDI(i));


end


fprintf('==============================================================\n')






%% =====================================================
% 表格输出
% =====================================================


Result=table(...
    files,...
    P,...
    N,...
    C,...
    MeanPore,...
    Pn,...
    Nn,...
    Cn,...
    PEDI,...
    ...
    'VariableNames',...
    {
    'Image',...
    'Pore_area_ratio_P',...
    'Pore_density_N',...
    'Connectivity_C',...
    'Mean_pore_area',...
    'P_norm',...
    'N_norm',...
    'C_norm',...
    'PEDI'
    });



disp(Result)




writetable(Result,...
    'PEDI_results.xlsx');






%% =====================================================
% PEDI绘图
% =====================================================


figure


bar(PEDI)



set(gca,...
    'XTickLabel',files)


xlabel('Image')


ylabel('PEDI')


title('Pore Evolution Deterioration Index')


grid on






%% =====================================================
% 排序
% =====================================================


[value,index]=sort(PEDI,'descend');


fprintf('\nDeterioration ranking:\n')


for i=1:Nimg


    fprintf('%d : %s   %.4f\n',...
        i,...
        files{index(i)},...
        value(i));

end





%% =====================================================
% 归一化函数
% =====================================================


function y=normalization(x)


y=(x-min(x))./(max(x)-min(x)+eps);


end