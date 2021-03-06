# ######################
# ## loading packages ##
# ######################
# library(tidyverse)
# library(lubridate)
# library(tidyquant)
# library(bizdays)
# 
# 
# # initializing bizdays libraries
# load_rmetrics_calendars(2000:2020)
# bizdays.options$set(default.calendar="Rmetrics/NYSE")



# #####################
# ## reading in data ##
# #####################
# df_chain_desc <- 
#     read_csv("data_output/spy_weekly_2014_2018_chain_desc_NEW.csv")
# 
# df_chain_hist <-
#     read_csv("data_output/spy_weekly_2014_2018_chain_hist_NEW.csv")
# 
# df_opt_hist <- 
#     read_csv("data_output/spy_weekly_2014_2018_opt_hist_NEW.csv")
# 
# df_pnl <- 
#     read_csv("data_output/spy_weekly_2014_2018_pnl_master_NEW.csv")
# 
# df_trade <- 
#     read_csv("data_output/spy_weekly_2014_2018_trade_master_NEW.csv")
# 



# #####################
# ## all trade dates ##
# #####################
# df_td_all <- 
#     tibble(
#         trade_date = bizseq(from = "2014-01-03", to = "2018-12-29")
#     )
# 
# ###################################################
# ## grabbing price data from yahoo with tidyquant ##
# ###################################################
# df_underlying_px <- 
#     tq_get("SPY", from = "2014-01-03", to = "2018-12-29")
# 
# 
# ########################################################
# ## grabbing volatility index from FRED with tidyquant ##
# ########################################################
# df_vol_index <-
#     tq_get(
#         "VIXCLS"
#         , get = "economic.data"
#         , from = "2014-01-03"
#         , to = "2018-12-29"
#     )





# ##########################################
# ## checking for dates with missing data ##
# ##########################################
# # description: these queries check for days with completely missing
# #  data, it's a crude check, but can catch if things are seriously wrong.
# 
# # df_chain_hist
# df_td_all %>% 
#     left_join(
#         df_chain_hist
#         , by = "trade_date"
#     ) %>% 
#     filter(is.na(underlying))
# 
# # df_opt_hist
# df_td_all %>% 
#     left_join(
#         df_opt_hist
#         , by = c("trade_date" = "data_date")
#     ) %>% 
#     filter(is.na(underlying_symbol))



# ###############################################
# ## check for differences in underlying price ##
# ###############################################
# # there are some fairly big differences, but nothing greater than 
# # 0.025% - so this shouldn't make a difference huge difference in 
# # the PNL calculations
# df_underlying_px %>% 
#     select(date, close) %>% 
#     left_join(
#         df_opt_hist %>% select(data_date, underlying_price)
#         , by = c("date" = "data_date")
#     ) %>% 
#     filter(abs((close - underlying_price)/close) > 0.0025) %>% 
#     group_by(date) %>% 
#     summarize(
#         close = mean(close)
#         , underlying_price = mean(underlying_price)
#     ) %>% 
#     mutate(
#         diff = close - underlying_price
#     ) 


# #################################################
# ## checking for missing price data for options ##
# #################################################
# # description: each option should have n + 1 rows in df_opt_hist,
# # where n is the d2x on execution date.
# df_opt_hist %>% 
#     group_by(
#         underlying_symbol, type, expiration, strike
#     ) %>% 
#     summarize(
#         row_count = n()
#     ) %>%
#     left_join(
#         df_chain_desc %>% select(expiration, d2x)
#         , by = "expiration"
#     ) %>% 
#     filter(row_count != (d2x + 1)) 
    



# ###################################
# ## basic checks on df_chain_desc ##
# ###################################
# # 1) make sure there are no chains with less than
# #    four days to expiration
# df_chain_desc %>% 
#     filter(d2x < 4)
# 
# 
# # 2) make sure there are at least 6 options per chain
# df_chain_desc %>% 
#     filter(num_opts < 6)
# 
# # 3) make sure exec_day_volume is greater than 1000
# df_chain_desc %>% 
#     filter(exec_day_volume < 1000)




# ################################################
# ## checking that changes in bid iv make sense ##
# ################################################
# dt_all <- bizseq(ymd(20140103), ymd(20181228))
# df_td_all <- tibble(trade_date = dt_all)
# 
# # this is the graph of execution date bid swap rates
# # it's an interesting visual, but it's hard to garner much
# # data integrity 
# df_chain_hist %>% 
#     left_join(
#         df_chain_desc %>% select(expiration, execution, realized_vol)
#         , by = "expiration"
#     ) %>% 
#     filter(trade_date == execution) %>% 
#     ggplot() +
#         geom_line(aes(x=trade_date, y=bid_swap_rate), color="red") +
#         geom_line(aes(x=trade_date, y=realized_vol), color="blue")
# 
# 
# # there should be a spike in implied volatility the week after there
# # is a spike in implied volatility.  Check that this is the case.
# df_real_iv_comparison <- 
#     df_chain_hist %>% 
#     left_join(
#         df_chain_desc %>% 
#             select(expiration, execution, realized_vol, return)
#         , by = "expiration"
#     ) %>% 
#     filter(trade_date == execution) %>% 
#     select(
#         expiration, execution, bid_swap_rate, realized_vol, return
#     ) %>% 
#     mutate(
#         realized_change = realized_vol - lag(realized_vol)
#         , iv_change = bid_swap_rate - lag(bid_swap_rate)
#     )
# 
# 
# # looking at the subsequent change in vol for each expiration
# df_real_iv_comparison <- 
#     df_real_iv_comparison %>% 
#         mutate(
#             subseq_iv_change = lead(iv_change)
#         )
# 
# 
# # there shouldn't be too many of these:
# # (1) a sizeable jump in realized vol (> 5%)
# # (2) the underlying experienced a loss during the expiration (< 0%)
# # (3) a sizeable drop in implied vol (< -2%)
# df_real_iv_comparison %>% 
#     filter(realized_change > 0.05) %>% 
#     filter(return < 0) %>% 
#     filter(subseq_iv_change < -0.02)


# ###############################################################
# ## checking the bid-IVs are consistent with volatility index ##
# ###############################################################
# df_index_comparison <- 
#     df_chain_hist %>% 
#         select(underlying, expiration, trade_date, bid_swap_rate) %>% 
#         left_join(
#             df_chain_desc %>% 
#                 select(expiration, execution, realized_vol, return)
#             , by = "expiration"
#         ) %>% 
#         filter(trade_date == execution) %>% 
#         left_join(
#             df_vol_index %>%
#                 mutate(vol_index = price / 100) %>% 
#                 select(date, vol_index)
#             , by = c("trade_date" = "date")
#         )
# 
# 
# # calculating the difference between the bid swap rate and the vol_index
# df_index_comparison <- 
#     df_index_comparison %>% 
#         mutate(vol_diff = bid_swap_rate - vol_index)
# 
# 
# df_index_comparison %>% 
#     filter(abs(vol_diff) > 0.05)



# ###########################################################
# ## check that dh pnls match up with realized vol premium ##
# ###########################################################
# # premium by expiration
# df_prem_exp <- 
#     df_trade %>% 
#         filter(variation == 0.1) %>% 
#         group_by(
#             underlying_symbol
#             , expiration
#         ) %>% 
#         summarize(
#             premium = sum(bid)
#         )
# 
# # pnl by expiration
# df_pnl_exp <- 
#     df_pnl %>% 
#         filter(variation == 0.1) %>%
#         group_by(
#             underlying_symbol
#             , expiration
#         ) %>% 
#         summarize(
#             pnl = sum(dly_tot_pnl)
#         )
# 
# 
# 
# 
# # premium recieved and dh pnl for each expiration
# df_prem_vs_pnl <- 
#     df_prem_exp %>% 
#         left_join(
#             df_pnl_exp
#             , by = c("underlying_symbol", "expiration")
#         )
#      
# 
# # for each expiration, the bid swap rate and the realized vol
# df_vol_prem <- 
#     df_chain_desc %>% 
#         select(underlying, expiration, execution, realized_vol) %>% 
#         left_join(
#             df_chain_hist %>% 
#                 select(underlying, expiration, trade_date, bid_swap_rate)
#             , by = c("underlying", "expiration")
#         ) %>%
#         filter(trade_date == execution) %>% 
#         select(underlying, expiration, realized_vol, bid_swap_rate) %>% 
#         mutate(
#             vol_prem = bid_swap_rate - realized_vol
#         )
# 
# # a final report that puts together all the numbers that we are
# # interested in
# df_report <- 
#     df_prem_vs_pnl %>% 
#         left_join(
#             df_vol_prem
#             , by = c("underlying_symbol" = "underlying", "expiration")
#         ) %>% 
#         mutate(
#             pnl_ratio = pnl / premium
#         )
#    
# 
# # scatter plot of vol-premium vs PNL ratio
# df_report %>% 
#     ggplot() +
#     geom_point(aes(x = vol_prem, y = pnl_ratio))
# 
# 
# 
# 
# # directionally correct cases (206 of 260)
# df_report %>% 
#     filter(
#         (vol_prem > 0 & pnl_ratio > 0) |
#         (vol_prem < 0 & pnl_ratio < 0)
#     )
# 
# 
# # should have been winners but they were losers (20 of 260)
# df_report %>% 
#     filter(vol_prem > 0 & pnl_ratio < 0) %>% 
#     arrange(pnl_ratio)
# 
# # should have been losers but they were winners (34 of 260)
# df_report %>% 
#     filter(vol_prem < 0 & pnl_ratio > 0) %>% 
#     arrange(desc(pnl_ratio))
# 
# # looking at one particular case and confirming that I
# # agree with the numbers
# df_pnl %>% 
#     filter(variation == 0.1) %>% 
#     filter(expiration == "2018-01-05") %>% 
#     filter(type == "call") %>% 
#     select(underlying_price) %>% 
#     mutate(
#         ret = log(underlying_price) - log(lag(underlying_price))
#     ) %>% 
#     .$ret %>% sd(na.rm = TRUE) * sqrt(252)
    
##############
## OLD CODE ##
##############
# # no missing rows here
# df_chain_hist %>% 
#     filter(expiration == ymd(20150402))
# 
# # looking at df_opt_hist for a particular option
# df_opt_hist %>% 
#     filter(type == "call") %>% 
#     filter(underlying_symbol == "SPY") %>% 
#     filter(expiration == ymd(20150402)) %>% 
#     filter(strike == 206)
# 
# # looks like expiration date is missing for this chain
# df_opt_hist %>% 
#     filter(underlying_symbol == "SPY") %>% 
#     filter(expiration == ymd(20150402)) %>% 
#     filter(data_date == expiration)
# 
# 
# backtestr::option_chain(
#     trade_date = ymd(20150401)
#     , underlying = "SPY"
#     , expiration = ymd(20150402)
# )

