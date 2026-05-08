--RFM view

CREATE VIEW vw_rfm AS
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

--RFM result view

CREATE VIEW vw_rfm_result AS
SELECT 
    r.RFM,
    e.final_result,
    COUNT (DISTINCT e.id_student) AS student_count
FROM vw_rfm r
JOIN dim_enrollment e ON r.id_student = e.id_student
GROUP BY r.RFM, e.final_result

--Student performance view

CREATE VIEW vw_student_performance AS
SELECT 
    DISTINCT f.id_student,
    SUM(f.sum_click) AS total_clicks,
    AVG(a.score) AS avg_score,
    e.final_result,
    e.code_module
FROM fact_activity f
LEFT JOIN fact_assessment a ON f.id_student = a.id_student
LEFT JOIN dim_enrollment e ON f.id_student = e.id_student
GROUP BY f.id_student, e.final_result, e.code_module


