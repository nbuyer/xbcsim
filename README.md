# xbcsim
This project was developed using the Delphi/Pascal programming language to ​simulate keyboard and mouse input using an Xbox game controller. The purpose is to allow the controller to function as a remote control for the computer, just like a keyboard+mouse.


这个项目是以Delphi/Pascal语言开发的用XBox游戏手柄模拟键盘和鼠标输入, 其作用是让手柄像键盘/鼠标一样作为电脑遥控器使用.

```
Usage:
  g_cXCSimThrd := TXControllerSimThread.Create(g_nXBoxDevID{0}, g_nXCChkMS);
  ...
  FreeAndNil(g_cXCSimThrd);
```
