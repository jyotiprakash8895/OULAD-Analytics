--Cohort analysis queries:

--How many students passed vs failed vs withdrew per course?

SELECT 
	code_module,
	final_result,
	COUNT(DISTINCT id_student) result_count
FROM dim_enrollment
GROUP BY code_module,final_result
ORDER BY code_module,final_result;


--Which course has highest pass rate?

SELECT
	code_module,
	pass_count*100/total_student as pass_prct
FROM(
SELECT
	code_module,
	SUM(CASE WHEN final_result IN ('Pass','Distinction') THEN 1 ELSE 0 END) AS pass_count,
	COUNT(DISTINCT id_student) AS total_student
FROM dim_enrollment
GROUP BY code_module)x
ORDER BY pass_prct DESC;


--How does number of previous attempts affect final result?

SELECT
	num_of_prev_attempts,
	pass_count * 100 / total_student AS success_prct
FROM(
SELECT
	num_of_prev_attempts,
	COUNT(DISTINCT id_student)AS total_student,
	SUM(CASE WHEN final_result IN ('Pass','Distinction') THEN 1 ELSE 0 END) AS pass_count
FROM dim_enrollment
GROUP BY num_of_prev_attempts)x
ORDER BY success_prct DESC;


--Engagement queries:

--What is average total clicks per student per course?

WITH CTE AS(
SELECT
	code_module,
	id_student,sum(sum_click)AS total_click
FROM fact_activity
GROUP BY code_module,id_student)
SELECT 
	code_module,
	AVG(total_click)AS avrg_click
FROM CTE
GROUP BY code_module
ORDER BY avrg_click DESC;


--Which activity type (forum, quiz, resource) gets most clicks?

SELECT
	v.activity_type,
	SUM(a.sum_click)AS total_click
FROM fact_activity a
LEFT JOIN dim_vle v
ON a.id_site = v.id_site
GROUP BY v.activity_type
ORDER BY total_click DESC;


--Do students who click more tend to pass more?

WITH CTE AS(
SELECT
	id_student,
	SUM(sum_click) AS click
FROM fact_activity
GROUP BY id_student)
SELECT 
	AVG(c.click)AS avrg_click,
	e.final_result
FROM CTE c
LEFT JOIN dim_enrollment e
ON c.id_student = e.id_student
GROUP BY e.final_result
ORDER BY avrg_click DESC;


--Funnel drop-off queries:

--How many students registered but never clicked anything?

SELECT
	e.code_module,
	COUNT(DISTINCT e.id_student)AS never_click
FROM dim_enrollment e
LEFT JOIN fact_activity a
ON e.id_student = a.id_student
WHERE a.sum_click IS NULL
GROUP BY e.code_module
ORDER BY never_click DESC


--At which week do most students stop engaging?

WITH CTE AS(
SELECT
	id_student,
	MAX(date)/7 AS last_week
FROM fact_activity
WHERE date >= 0
GROUP BY id_student)
SELECT
	last_week,
	COUNT(id_student)AS student_count
FROM CTE
GROUP BY last_week
ORDER BY last_week DESC


--How many students submitted all assessments vs dropped off midway?

Attempted: compare student submissions vs total assessments per course
Issue: JOIN filters total count by student submissions
making submitted always equal to total
Status: known limitation, to be revisited

--RFM queries:
--R = Recency   → how recently did student last click?
--F = Frequency → how many times did student visit?
--M = Monetary  → how much effort did student put in?

--Segment students by recency of last click, frequency of sessions, total clicks

WITH CTE AS(
SELECT
	id_student,
	MAX(date)AS last_click,
	COUNT(DISTINCT date)AS sessions,
	SUM(sum_click) AS total_click
FROM fact_activity
GROUP BY id_student)
SELECT 
	id_student,
	CASE
		WHEN R=1 AND F=1 AND M=1 THEN 'Champion'
		WHEN R=1 AND F=3 AND M=3 THEN 'Promising'
		WHEN R=3 AND F=1 AND M=1 THEN 'At Risk'
		WHEN R=2 AND F=2 AND M=2 THEN 'Average'
		WHEN R=3 AND F=3 AND M=3 THEN 'Lost'
		ELSE 'Needs Attention'
	END AS RFM
FROM(SELECT
	id_student,
	NTILE(3) OVER(ORDER BY last_click DESC)AS R,
	NTILE(3) OVER(ORDER BY sessions DESC)AS F,
	NTILE(3) OVER(ORDER BY total_click DESC)AS M
FROM CTE)x
ORDER BY RFM
