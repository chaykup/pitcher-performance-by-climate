-- View for pitchers with 500+ innings (2020-2025)
CREATE VIEW qualified_pitchers AS
SELECT 
    p.pitcher_id,
    p.first_name,
    p.last_name,
    SUM(pgs.innings_pitched) as total_innings
FROM pitchers p
JOIN pitcher_game_stats pgs ON p.pitcher_id = pgs.pitcher_id
JOIN games g ON pgs.game_id = g.game_id
WHERE g.game_date BETWEEN '2020-01-01' AND '2025-12-31'
GROUP BY p.pitcher_id, p.first_name, p.last_name
HAVING SUM(pgs.innings_pitched) >= 500;

-- View combining game stats with climate data
CREATE VIEW pitcher_stats_with_climate AS
SELECT 
    pgs.*,
    g.game_date,
    g.ballpark_id,
    bp.ballpark_name,
    bp.elevation_ft,
    bc.temperature_f,
    bc.humidity_pct,
    bc.precipitation_in
FROM pitcher_game_stats pgs
JOIN games g ON pgs.game_id = g.game_id
JOIN ballparks bp ON g.ballpark_id = bp.ballpark_id
LEFT JOIN ballpark_climate bc ON bp.ballpark_id = bc.ballpark_id 
    AND g.game_date = bc.game_date;

-- Comments for views
COMMENT ON VIEW qualified_pitchers IS 'Pitchers with 500+ innings pitched between 2020-2025';
COMMENT ON VIEW pitcher_stats_with_climate IS 'Pitcher statistics combined with climate data for analysis';