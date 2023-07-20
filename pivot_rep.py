import pandas as pd
import numpy as np

def build_pivot():
    df = pd.read_excel('C:/Users/User/Documents/tests/RC/file1.xlsm')

    conditions = [
        (df['Просрочка, дней'] == 0),
        (df['Просрочка, дней'] > 0) & (df['Просрочка, дней'] <= 30),
        (df['Просрочка, дней'] > 30) & (df['Просрочка, дней'] <= 60),
        (df['Просрочка, дней'] > 60) & (df['Просрочка, дней'] <= 90),
        (df['Просрочка, дней'] > 90)
    ]
    values = ['Без просрочки', 'Просрочка 0-30 дней', 'Просрочка 31-60 дней', 'Просрочка 61-90 дней', 'Просрочка 91+ дней']

    df['Тип просрочки'] = np.select(conditions, values)
    pivot_df = pd.pivot_table(df, values='id', index=['Дата', 'Тип просрочки', 'Тип обязательства'],
                              columns=['Первоначальный кредитор'], aggfunc={'id': 'count'}, fill_value=0)
    with pd.ExcelWriter('C:/Users/User/Documents/tests/RC/file1.xlsm', mode='a', if_sheet_exists='replace') as writer:
        pivot_df.to_excel(writer, sheet_name='Лист2')


build_pivot()