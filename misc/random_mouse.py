import pyautogui
from random import randint

x, y = pyautogui.size()
num_mvmts = int(input('How many mouse movements should we perform? '))

for i in range(num_mvmts):
    x, y = (randint(500, 1290), randint(325, 817))
    pyautogui.moveTo(x, y, duration = 0.00001)
