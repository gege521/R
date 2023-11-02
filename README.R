library(openxlsx)
library(sqldf)
library(tidyverse)

##名单
userid_exp_base <- getMifiJdbcQueryws(" 	

select 
date(from_unixtime(unix_timestamp(cast(date as string), 'yyyyMMdd'),'yyyy-MM-dd')) as dt,
cast(userid as string) userid,
policy_name exp_name,
policy_type adj_type,
test_control exp_control,
sub_test_control,
is_active,
new_amount  new_line,
current_amount  basic_line,
current_rate user_rate,
new_rate  new_rate
from abtest_invoke_record 
where date > 20230101
 ")
userid_exp_base %>% group_by(dt) %>% summarize(cnt = n())


##剔除**用户后实验名单
userid_exp_exclude <- left_join(userid_exp_base, gan_credit, by = c("userid","dt") ) %>% filter(is.na(user_id))

##检查数据
#userid_exp_exclude_zhongan %>% group_by(dt) %>% summarize(cnt = n())

##调额调价后响应复购
reloan <- getMifiJdbcQuery("  select 
cast(userid as string) userid,
date(from_unixtime(unix_timestamp(cast(effective_date as string), 'yyyyMMdd'),'yyyy-MM-dd'))  effective_date, 
sum(prin)/100 prin,  --复购放款
sum(prin*rate)/10000 as prin_rate  
from loaning_contract_fact 
where date = 20231026
and effective_date > 20230101  
and is_cash = 1  
AND rule_id != 452 
group by 1,2 ")
	 
##复购借据风险表现
reloan_risk <- getMifiJdbcQueryws("  select 
cast(userid as string) userid, 
date(from_unixtime(unix_timestamp(cast(effective_date as string), 'yyyyMMdd'),'yyyy-MM-dd'))  effective_date, 
sum(if(b.term_end_date_diff >= 1 and is_ovd_d1 = 1, b.prin, 0)) ovd_1,
sum(if(b.term_end_date_diff >= 7 and is_ovd_d7 = 1, b.prin, 0)) ovd_7,
sum(if(b.term_end_date_diff >= 30 and is_ovd_d30 = 1, b.prin, 0)) ovd_30,
sum(if(b.term_end_date_diff >= 1, b.prin, 0)) as fpd1,   
sum(if(b.term_end_date_diff >= 7, b.prin, 0)) as fpd7,
sum(if(b.term_end_date_diff >= 30, b.prin, 0)) as fpd30,

sum(if(b.term_end_date_diff >= 1 and is_ovd_d1 = 1, b.prin_unrepay, 0)) ovd1_old,
sum(if(b.term_end_date_diff >= 1 and is_ovd_d7 = 1, b.prin_unrepay, 0)) ovd7_old,
sum(if(b.term_end_date_diff >= 1 and is_ovd_d30 = 1, b.prin_unrepay, 0)) ovd30_old,

sum(if(b.term_end_date_diff >= 1, b.prin_unrepay, 0)) as fpd1_old,
sum(if(b.term_end_date_diff >= 7, b.prin_unrepay, 0)) as fpd7_old,
sum(if(b.term_end_date_diff >= 30, b.prin_unrepay, 0)) as fpd30_old,
count(case when b.term_end_date_diff >= 7 then 1 end) as fpd7_contract_cnt,

sum(mob2_ovd_bal) ovd_mob2,
sum(prin_mob2) as prin_mob2,
sum(mob3_ovd_bal) ovd_mob3,
sum(prin_mob3) as prin_mob3,
sum(mob4_ovd_bal) ovd_mob4,
sum(prin_mob4) as prin_mob4,
sum(mob7_ovd_bal) ovd_mob7,
sum(prin_mob7) as prin_mob7
from  
  (
    select 
    con_id, prin, effective_date, userid
    from loaning_contract_fact 
    where date = 20231025
    and effective_date >= 20230101  
    and is_cash = 1
    AND rule_id != 452 --非众安
  ) a
  join 
  (
    select con_id, term_end_date_diff, con_prin prin, prin prin_unrepay, is_ovd_d1,is_ovd_d7,is_ovd_d30
    from term_info_fact 
    where date = 20231025
      and term_no = 1
      and effective_date >= 20230101
  ) b on a.con_id = b.con_id
  join 
  (
    select
      con_id,
      max(if(pay_absolute_months = 2 and ovd_days > 30, balance, 0)) as mob2_ovd_bal,
      max(if(pay_absolute_months = 3 and ovd_days > 30, balance, 0)) as mob3_ovd_bal,
      max(if(pay_absolute_months = 4 and ovd_days > 30, balance, 0)) as mob4_ovd_bal,
      max(if(pay_absolute_months = 7 and ovd_days > 30, balance, 0)) as mob7_ovd_bal,
      
      max(if(pay_absolute_months = 2, prin, 0)) as prin_mob2,
      max(if(pay_absolute_months = 3, prin, 0)) as prin_mob3,
      max(if(pay_absolute_months = 4, prin, 0)) as prin_mob4,
      max(if(pay_absolute_months = 7, prin, 0)) as prin_mob7
      
    from loaning_contract_vintage 
    where `date` = 20231025
      and effective_date >= 20230101
      and is_cash = 1
    group by 1
  ) c on a.con_id = c.con_id
group by 1,2 ")
	 

#vintage m1+ & 放款留存率
reloan_risk_mob <- getMifiJdbcQueryws("  
select
cast(userid as string) userid, 
date(from_unixtime(unix_timestamp(cast(effective_date as string), 'yyyyMMdd'),'yyyy-MM-dd'))  effective_date, 
pay_absolute_months as mob,
sum(prin/100) as prin,
sum(IF(ovd_days>0, 0, balance/100)) AS curr_balance, --生息余额（额度定价模板使用）
sum(IF(ovd_days>30, balance/100, 0)) AS dpd30_balance --计算MOB 30+
from loaning_contract_vintage 
where `date` = 20231016
and effective_date >= 20230101
and is_cash = 1
group by 1,2,3
                                  "
)

userid_exp_base %>%
distinct(userid) %>%
summarise(cnt = n())	 

#T0余额=============================================================================
retention_t0 <- getMifiJdbcQuery(" 

select
adj_type,
t1.dt,
exp_name,
exp_control,
sum(pay_cash_balance)/count(1)/100 t0_balance
from 
(select cast(userid as string) userid1, date(dt) dt1, * from hive_zjyprc_hadoop.ods.abtest_invoke_record_exclude_zhongan) t1
join
(
select
userid,
pay_cash_balance,
user_rate,
date(from_unixtime(unix_timestamp(cast(date as string), 'yyyyMMdd'),'yyyy-MM-dd'))  dt
from
mifidw_loaning_fact  
where  date 
in (20230103,
    20230216,
    20230217,
    20230224,
    20230313,
    20230314,
    20230407,
    20230420,
    20230429,
    20230513,
    20230519,
    20230527,
    20230530,
    20230612,
    20230701,
    20230707,
    20230722,
    20230731,
    20230810,
    20230811,
    20230911,
    20230915
) ) t2
on t1.userid1 = t2.userid and t1.dt1= t2.dt
group by 1,2,3,4
order by 1,2,3,4 desc
")

   
                                 	                                  
	                                  
#T60余额=============================================================================	 
retention_t60 <- getMifiJdbcQuery(" 

select
adj_type,
t1.dt,
exp_name,
exp_control,
sum(pay_cash_balance)/count(1)/100 t60_balance
from 
(select cast(userid as string) userid1,date(dt) + 60 as dt1, * from abtest_invoke_record_exclude) t1
join
(
select
userid,
pay_cash_balance,
user_rate,
date(from_unixtime(unix_timestamp(cast(date as string), 'yyyyMMdd'),'yyyy-MM-dd'))  ods_day
from
mifidw_loaning_fact  
where  date 
in (
20230304,
20230417,
20230418,
20230425,
20230512,
20230513,
20230606,
20230619,
20230628,
20230712,
20230718,
20230726,
20230729,
20230811,
20230830,
20230905,
20230920,
20230929,
20231009,
20231010,
20231110,
20231114
) ) t2
on t1.userid1 = t2.userid and t1.dt1 = t2.ods_day
group by 1,2,3,4
order by 1,2,3,4 desc
")

sample_retention <- getMifiJdbcQuery("select cast(userid as string) userid1,date(dt) + 60 as dt1, * from abtest_invoke_record_exclude_zhongan limit 100")                                  
                                                                                                  
#retention_t60 %>% group_by(dt) %>% summarize(cnt = n())
#最终分析名单-补充投放时余额数据
#userid_exp_exclude_zhongan_addinfo <- left_join(userid_exp_exclude_zhongan, retention_t0,by = c("userid","dt")) 
#rm(userid_exp_exclude_zhongan)

#实验基础数据=========================================================================================

base_summary <- sqldf("
select 
adj_type,
dt,
exp_name,
exp_control,
count(1) cnt,
sum(basic_line)/COUNT(1) basic_line, 
sum(new_line)/COUNT(1) new_line, 
sum(new_line-basic_line)/count( userid) AS amt_chg,
sum(new_line)/sum(basic_line)-1 AS amt_chg_rate,
sum(user_rate)/COUNT(1)/10000*3.6 user_rate,
sum(new_rate)/COUNT(1)/10000*3.6 new_rate,
sum(360*(new_rate-user_rate)/1000000)/count( userid) AS rate_chg,
sum(new_rate)/sum(user_rate)-1 AS rate_chg_rate
from   userid_exp_exclude_zhongan 
group by 1,2,3,4
order by 1,2,3,4 desc
")

write.xlsx(base_summary, "base_summary.xlsx", colNames = TRUE)

#复购汇总===========================================================================================

reloan_fix <- userid_exp_exclude_zhongan %>% 
left_join(reloan, by = "userid") %>%
mutate(reloan_days = as.Date(effective_date) - as.Date(dt))
reloan_fix$reloan_days <- as.integer(reloan_fix$reloan_days)

reloan_summary <- sqldf("
select 
dt,
exp_name,
exp_control,
adj_type,
sum(case when reloan_days between 0 and 30 then  prin else 0 end) t30_prin,
sum(case when reloan_days between 0 and 30  then prin_rate else 0 end) as t30_prin_rate,
count(distinct case when reloan_days between 0 and 30  then userid end) t30_prin_cnt,
sum(case when reloan_days between 0 and 60 then  prin else 0 end) t60_prin,
sum(case when reloan_days between 0 and 60  then prin_rate else 0 end) as t60_prin_rate,
count(distinct case when reloan_days between 0 and 60  then userid end) t60_prin_cnt 
from   reloan_fix 
group by 1,2,3,4 "
)

#风险汇总==================================================================================================

reloan_risk_fix <- userid_exp_exclude_zhongan %>% 
left_join(reloan_risk, by = "userid") %>%
mutate(reloan_days = as.Date(effective_date) - as.Date(dt))

reloan_risk_fix$reloan_days <- as.integer(reloan_risk_fix$reloan_days)
#rm(reloan_risk)

risk_summary <- sqldf("
select 
dt,
exp_name,
exp_control,
adj_type,
count(case when ovd_1 > 0 and reloan_days between 0 and 60 then 1 end) ovd1_cnt,
count(case when ovd_7 > 0 and reloan_days between 0 and 60 then 1 end) ovd7_cnt,
sum(case when reloan_days between 0 and 60 then ovd_1 end) ovd_1,
sum(case when reloan_days between 0 and 60 then ovd_7 end) ovd_7,
sum(case when reloan_days between 0 and 60 then fpd1 end) as fpd1,    
sum(case when reloan_days between 0 and 60 then fpd7 end) as fpd7,
sum(case when reloan_days between 0 and 60 then fpd30 end) as fpd30,
sum(case when reloan_days between 0 and 60 then ovd_30 end) as ovd_30,
sum(case when fpd7_contract_cnt >= 1 and reloan_days between 0 and 60 then 1 else 0 end) fpd7_cnt,
sum(case when reloan_days between 0 and 60 then ovd1_old end) ovd1_old,
sum(case when reloan_days between 0 and 60 then ovd7_old end) ovd7_old,
sum(case when reloan_days between 0 and 60 then ovd30_old end) ovd30_old,
sum(case when reloan_days between 0 and 60 then fpd1_old end) as fpd1_old,
sum(case when reloan_days between 0 and 60 then fpd7_old end) as fpd7_old,
sum(case when reloan_days between 0 and 60 then fpd30_old end) as fpd30_old,
sum(case when reloan_days between 0 and 60 then ovd_mob2 end) ovd_mob2,
sum(case when reloan_days between 0 and 60 then prin_mob2 end) as prin_mob2,
sum(case when reloan_days between 0 and 60 then ovd_mob3 end) ovd_mob3,
sum(case when reloan_days between 0 and 60 then prin_mob3 end) as prin_mob3,
sum(case when reloan_days between 0 and 60 then ovd_mob4 end) ovd_mob4,
sum(case when reloan_days between 0 and 60 then prin_mob4 end) as prin_mob4,
sum(case when reloan_days between 0 and 60 then ovd_mob7 end) ovd_mob7,
sum(case when reloan_days between 0 and 60 then prin_mob7 end) as prin_mob7
from  reloan_risk_fix t1  
group by 1,2,3,4"
)


reloan_risk_mob <- userid_exp_exclude_zhongan %>% 
left_join(reloan_risk_mob, by = "userid") %>%
mutate(reloan_days = as.Date(effective_date) - as.Date(dt))

reloan_risk_mob$reloan_days <- as.integer(reloan_risk_mob$reloan_days)


risk_vintage <- sqldf("
select 
dt,
exp_name,
exp_control,
adj_type,
sub_test_control,
case when pay_cash_balance > 0 then '在贷' else '结清' end user_status,
mob,
sum(case when reloan_days between 0 and 60 then prin end) prin,
sum(case when reloan_days between 0 and 60 then dpd30_balance end) dpd30_balance,
sum(case when reloan_days between 0 and 60 then curr_balance end) curr_balance
from  reloan_risk_mob t1  
group by 1,2,3,4,5,6,7"
)



#所有指标汇总==================================================================================================

all_summary <- sqldf("

SELECT t1.*,
t30_prin/cnt t30_avg_prin,
t30_prin_rate/t30_prin*3.6/100 t30_prin_rate,
t30_prin_cnt*1.0/cnt t30_reloan_rate,
t30_prin_cnt,
t60_prin/cnt t60_avg_prin,
t60_prin_rate/t60_prin*3.6/100 t60_prin_rate,
t60_prin_cnt*1.0/cnt t60_reloan_rate,
t0_balance,
t60_balance,

cast(ovd7_cnt as double)/cast(fpd7_cnt as double) fpd7_cnt_risk,
ovd_7/fpd7 fpd7_risk,
ovd_30/fpd30 fpd30,

ovd7_old/fpd7_old as fpd7_old,
ovd30_old/fpd30_old as fpd30_old,

ovd_mob2/prin_mob2 m1_mob2,
ovd_mob3/prin_mob3 m1_mob3,
ovd_mob4/prin_mob4 m1_mob4,
ovd_mob7/prin_mob7 m1_mob7,
  
ovd_7,
fpd7,
fpd7_old,
fpd7_cnt
from base_summary t1 
left join risk_summary t3 
on t1.exp_control = t3.exp_control and t1.exp_name = t3.exp_name and t1.dt = t3.dt and t1.adj_type = t3.adj_type 
left join retention_t0 t4
on t1.exp_control = t4.exp_control and t1.exp_name = t4.exp_name and t1.dt = t4.dt and t1.adj_type = t4.adj_type 
left join retention_t60 t2
on t1.exp_control = t2.exp_control and t1.exp_name = t2.exp_name and t1.dt = t2.dt and t1.adj_type = t2.adj_type
left join reloan_summary t5
on t1.exp_control = t5.exp_control and t1.exp_name = t5.exp_name and t1.dt = t5.dt and t1.adj_type = t5.adj_type 

")

#all_summary$new_line <- as.numeric(all_summary$new_line)
#all_summary$basic_line <- as.numeric(all_summary$basic_line)

write.xlsx(all_summary, "all_summary.xlsx", colNames = TRUE)

