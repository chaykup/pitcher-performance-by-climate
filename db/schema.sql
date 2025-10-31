-- Teams table
CREATE TABLE teams (
    team_id SERIAL PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    team_abbr VARCHAR(5) NOT NULL UNIQUE,
    city VARCHAR(100) NOT NULL,
    CONSTRAINT team_name_unique UNIQUE (team_name)
);

-- Ballparks table
CREATE TABLE ballparks (
    ballpark_id SERIAL PRIMARY KEY,
    ballpark_name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50),
    elevation_ft INTEGER NOT NULL,
    team_id INTEGER REFERENCES teams(team_id),
    CONSTRAINT ballpark_name_unique UNIQUE (ballpark_name)
);

-- Pitchers table
CREATE TABLE pitchers (
    pitcher_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    mlb_id VARCHAR(20) UNIQUE, -- For external MLB API integration
    CONSTRAINT pitcher_name_unique UNIQUE (first_name, last_name, mlb_id)
);

-- Games table
CREATE TABLE games (
    game_id SERIAL PRIMARY KEY,
    game_date DATE NOT NULL,
    home_team_id INTEGER NOT NULL REFERENCES teams(team_id),
    away_team_id INTEGER NOT NULL REFERENCES teams(team_id),
    ballpark_id INTEGER NOT NULL REFERENCES ballparks(ballpark_id),
    home_score INTEGER,
    away_score INTEGER,
    CONSTRAINT different_teams CHECK (home_team_id != away_team_id),
    CONSTRAINT game_unique UNIQUE (game_date, home_team_id, away_team_id)
);

-- Pitcher game stats table (main stats table)
CREATE TABLE pitcher_game_stats (
    stat_id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL REFERENCES games(game_id),
    pitcher_id INTEGER NOT NULL REFERENCES pitchers(pitcher_id),
    pitcher_team_id INTEGER NOT NULL REFERENCES teams(team_id),
    opponent_team_id INTEGER NOT NULL REFERENCES teams(team_id),
    result VARCHAR(1) CHECK (result IN ('W', 'L', 'N', 'S')), -- Win, Loss, No Decision, Save
    innings_pitched DECIMAL(4,1) NOT NULL CHECK (innings_pitched >= 0),
    hits_allowed INTEGER NOT NULL CHECK (hits_allowed >= 0),
    runs_allowed INTEGER NOT NULL CHECK (runs_allowed >= 0),
    earned_runs INTEGER NOT NULL CHECK (earned_runs >= 0),
    homeruns_allowed INTEGER NOT NULL CHECK (homeruns_allowed >= 0),
    walks INTEGER NOT NULL CHECK (walks >= 0),
    strikeouts INTEGER NOT NULL CHECK (strikeouts >= 0),
    batters_hit INTEGER NOT NULL CHECK (batters_hit >= 0),
    era DECIMAL(5,2) CHECK (era >= 0.00),
    fip DECIMAL(5,2) CHECK (fip >= 0.00),
    CONSTRAINT different_teams_stats CHECK (pitcher_team_id != opponent_team_id),
    CONSTRAINT earned_runs_valid CHECK (earned_runs <= runs_allowed),
    CONSTRAINT pitcher_game_unique UNIQUE (game_id, pitcher_id)
);

-- Climate data table
CREATE TABLE ballpark_climate (
    climate_id SERIAL PRIMARY KEY,
    ballpark_id INTEGER NOT NULL REFERENCES ballparks(ballpark_id),
    game_date DATE NOT NULL,
    temperature_f DECIMAL(5,2), -- Fahrenheit
    humidity_pct DECIMAL(5,2) CHECK (humidity_pct >= 0 AND humidity_pct <= 100),
    precipitation_in DECIMAL(5,3) CHECK (precipitation_in >= 0), -- Inches
    CONSTRAINT ballpark_date_unique UNIQUE (ballpark_id, game_date)
);

-- Indexes for performance
CREATE INDEX idx_pitcher_game_stats_pitcher ON pitcher_game_stats(pitcher_id);
CREATE INDEX idx_pitcher_game_stats_game ON pitcher_game_stats(game_id);
CREATE INDEX idx_pitcher_game_stats_team ON pitcher_game_stats(pitcher_team_id);
CREATE INDEX idx_games_date ON games(game_date);
CREATE INDEX idx_games_ballpark ON games(ballpark_id);
CREATE INDEX idx_climate_ballpark_date ON ballpark_climate(ballpark_id, game_date);
CREATE INDEX idx_pitchers_name ON pitchers(last_name, first_name);

-- Comments for documentation
COMMENT ON TABLE pitcher_game_stats IS 'Individual pitcher statistics for each game appearance';
COMMENT ON TABLE ballpark_climate IS 'Climate conditions at ballparks on game days';
COMMENT ON COLUMN pitcher_game_stats.innings_pitched IS 'Stored as dec