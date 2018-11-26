# R
1.工具包推荐及说明：
1.1 数据可视化包：

ggplot2: 不用我多说，懂R的都知道这个包

plotly：绘制可交互式图形，而且和ggplot2有深度整合

leaflet: 绘制可交互式地图的不二选择，语法简单，而且完美支持管道运算符

ggforce：图片放大数据包，可以放大指定区域图像

ggrepel：ggplot2的注释补充包，可以通过更加美观的方式添加注释

treemapify：绘制树状图的ggplot2补充包

ggridges：ggplot2的脊线图补充

alluvial，ggalluvial：冲积图

shiny：不用网页开发也可以写自己的网站

1.2 机器学习包：

caret：类似于python的sciki-learn包，提供多种算法的api，同时也有交叉验证，数据预处理等函数，相当强大

randomForest：最忠实于原文献的随机森林算法包

xgboost：大名鼎鼎的xgboost，kaggle高位利器

arules：关联算法

C50：C50决策树算法包

rpart：CART决策树算法

e1071：SVM和Naive Bayes

glmnet：lasso以及ridge回归算法

nnet，neuralnet：神经网络算法

h2o，mxnet，tensorflow，keras：深度学习框架

（KNN，Kmeans等算法貌似有自带函数）

1.3 数据操作：

dplyr：操作数据矿的神器，谁用谁知道

plyr：list，array，dataframe三者的神奇变化包

data.table：数据IO和操作神器

tidyr：处理脏数据

tidytext：分词以及词频提取

stringr：处理字符串的神包

jiebaR，tm：中文分词利器，NLP专用

purrr：apply函数的绝佳替代

lubridate：时间处理最好的包，没有之一

broom：将各种统计学模型结果数据框化

tidyverse：RStudio出品的集成包，数据科学一揽子解决方案

magrittr：管道符

1.4 数据读取

data.table：最高支持100G数据，fread和fwrite快的你不敢想，还支持数据类型判断

readr：RStudio出品，完美替代原生数据IO函数

readxl，openxlsx：读写excel文件

1.5 缺失值处理包：

VIM：可视化缺失情况

Hmisc：处理缺失值

mice：利用各种算法补全缺失值的包

1.6 rmarkdown系列：

knitr：完美将markdown转化成pdf和html

rmarkdown：markdown的核心包

1.7 数据展示：

kableExtra：数据框的表格展示，支持Bootstrap样式

DT：js库DataTables和R的完美结合

1.8 其他：

zoo，forcats：时间序列

pROC，ROCR：绘制ROC曲线

wordcloud，wordcloud2：词云

igraph：网络图以及pagerank算法

network3D：结合D3.js

survival：生存分析

DBI：和SQL的交互
