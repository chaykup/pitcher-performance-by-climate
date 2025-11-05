import pandas as pd
import os

base_directory = '/Users/jacobsii/repos/pitcher-performance-by-climate/'
data_path = os.path.join(base_directory, 'data','active_pitchers_game_splits_2020_2025.csv')

df = pd.read_csv(data_path)

df.drop(['season'], axis=1, inplace=True)

print(df.head())