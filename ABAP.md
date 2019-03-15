# ABAP LEARNING RECORDS
### TIPS：
- **快捷键** :
    - Shift + F1 : 格式化
    - Ctrl + F1 : 编辑/查看切换
    - Ctrl + F2 : 编译检查
    - Ctrl + F3 : 激活
    - Ctrl + F6 : 调用function等
    - Ctrl + 「< / >」 : 批量注释/取消注释
    - Ctrl + D : 快速复制粘贴选择的某一行代码

### TECHNICAL SUMMARY：
- **创建内表时：先定义结构，按参照结构定义内表**
- **对标准数据库表的修改，需要调用BAPI处理**
- **数据处理需要先分组，不能一行一行调用BAPI处理，因为系统存在缓存，修改单据是需要锁定后才能处理。
    Eg : 当前锁定处理第一条单据，之后没有及时解锁，第二条数据便无法处理，因而漏处理一条数据，出现bug**
- **方法调用**：
    - _当是静态方法「static method」时，使用 "class=>method" ；_
    - _当为实例方法「instance method」时，使用 "class->method"；_
***
- **代码规范**：
    - _变量命名要规范，固定使用一种。g代表全局，l代表本地，w代表工作区，t代表内表 ;_
    - _方法命名：用名词 + 动词，eg: `frm_check_data`;_
***
