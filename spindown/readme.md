These Script are a fix for TrueNas Community's "waking" of HDD which are in Standby. TrueNas wakes those drives every 90 Minutes to get S.M.A.R.T. Data from those drives. 

The Idea behind these Scripts is:
1. SMART-Data doesn't change when drives are spun down. The last available data is good enough -> last state should be cached and returned on request.
2. SMART-Checks can be delayed until drives exit standby for other tasks.
3. SMART-Checks for other drives should not be altered.
