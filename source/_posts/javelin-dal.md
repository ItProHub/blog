---
title: 手写一个微型 Spring 框架（四）：数据访问层设计实战
date: 2025-05-12 14:55:12
tags:
---

在前几篇文章中，我们已经完成了 Javelin 框架的核心功能构建，包括 HTTP 路由注册、注解扫描与 IoC 容器等内容。本篇将深入探讨 数据访问层（DAL，Data Access Layer） 的设计与实现，从理念到代码，全面展示如何在 Javelin 中构建一个灵活、可维护、可扩展的数据访问模块。

---

# 痛点驱动设计

在构建 Javelin 的数据访问层过程中，我们并不是一开始就拥有完整的设计蓝图，而是源于开发过程中反复遇到的一些实际痛点。下面列举几个典型问题，并结合示例代码说明 Javelin 是如何逐一解决这些问题的：

**1. JDBC 样板代码冗余、可读性差**

原始写法：

```java
Connection conn = DriverManager.getConnection(url, user, pwd);
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
ps.setInt(1, id);
ResultSet rs = ps.executeQuery();
if (rs.next()) {
    User user = new User();
    user.setId(rs.getInt("id"));
    user.setName(rs.getString("name"));
    return user;
}
```

问题：SQL 与 Java 混杂、资源管理复杂、字段映射重复。

Javelin 写法：

```java
User user = CPQueryFactory.create()
    .sql("SELECT * FROM users WHERE id = ?")
    .params(id)
    .queryOne(User.class);
```

通过 `CPQuery` 和 `BeanPropertyRowMapper` 简化了所有模板逻辑。

**2. 手动管理连接生命周期，易出错**

原始 JDBC 写法中，开发者需要自行处理连接关闭，若中间有异常，极易遗漏关闭：

```java
try {
    Connection conn = ...
    // do something
} catch (Exception e) {
    // handle
} finally {
    conn.close(); // 容易忘记
}
```

Javelin 使用 `DbContext` 实现 `AutoCloseable`，并结合 try-with-resources 自动释放资源：

```java
try (DbContext db = DbConnManager.createAppDb("test")) {
    // safe use
}
```

**3. 事务控制分散，耦合混乱**

在 JDBC 中常见写法：

```java
conn.setAutoCommit(false);
try {
    // 执行多条语句
    conn.commit();
} catch(Exception e) {
    conn.rollback();
}
```

Javelin 中的 `DbContext` 可以结合 `ThreadLocal` 保证一个线程内的事务连接复用，并支持后续统一事务管理器拓展。

**4. 单元测试困难**

传统 JDBC 紧耦合真实连接，测试时需要真实数据库支持。
Javelin 的抽象如 `DbContext` 与 `CPQuery` 均可通过接口注入和 Mock 替换，适合单元测试或内存数据库测试。

正是以上这些痛点——重复性高、维护成本大、可测试性差、事务管理易错——推动我们一步步抽象出 CPQuery、DbContext、EntityFactory 等组件，形成 Javelin 当前结构清晰、职责明确的数据访问模型。

# 整体设计思路

Javelin 的数据访问层设计秉承“职责清晰、分层解耦、灵活适配”的核心思想，整个数据访问层围绕以下几个核心目标展开：

1. 统一数据库连接管理：抽象数据库类型与连接池配置。

2. 简化 SQL 执行逻辑：封装 JDBC 的模板化操作。

3. 对象关系映射（ORM）初探：通过 BeanPropertyRowMapper 映射结果集。

4. 提供声明式查询构造器：提升 SQL 的可读性与复用性。

数据访问层主要由以下几个模块组成：

```
data/
├── DbConnManager.java        // 数据库连接池统一管理
├── DbContext.java            // 提供数据库上下文环境（连接获取、关闭）
├── command/
│   ├── CPQuery.java          // 核心查询对象，封装 SQL 执行模板
│   ├── CPQueryFactory.java   // 工厂类，创建 CPQuery 实例
│   └── BeanPropertyRowMapper.java // 结果集映射工具
├── config/
│   └── DbConfigProvider.java // 数据库配置信息提供器
└── DatabaseType.java         // 支持的数据库类型枚举
```

![框架](./images/javelin-dal/architecture.png)

---

# 核心类解析

## DbConnManager：连接池统一管理

`DbConnManager` 是一个典型的连接管理器类，负责初始化并维护数据库连接池（如 Druid、HikariCP）。它的职责包括：

* 从配置加载数据库信息；
* 创建与缓存连接池实例；
* 提供 `DataSource` 给上层组件调用。

**设计亮点**：

* 将连接池隔离成可插拔模块，支持多数据库；
* 懒加载初始化，优化资源占用；
* 支持连接池复用，避免重复创建。

---

## DbContext：数据库上下文载体

`DbContext` 承担着线程安全的数据库连接提供工作。它采用 `ThreadLocal` 管理当前线程的数据库连接，确保每个线程使用独立连接，避免并发问题。

**设计亮点**：

* 使用 `ThreadLocal<Connection>` 实现事务管理；
* 提供 `getConnection()`、`close()` 等静态方法统一访问；
* 解耦 SQL 执行逻辑与连接生命周期管理。

---

## CPQuery / CPQueryFactory：SQL 执行模板

`CPQuery` 是项目中的 JDBC 模板核心类，类似 Spring 的 `JdbcTemplate`。它封装了 PreparedStatement 的参数绑定、SQL 执行、结果映射等常见流程：

```java
CPQuery query = CPQueryFactory.create()
    .sql("SELECT * FROM user WHERE id = ?")
    .params(1);

User user = query.queryOne(User.class);
```

**设计亮点**：

* 提供链式编程接口，构造直观简洁；
* 支持 `queryList`, `queryOne`, `update`, `batch` 等通用操作；
* 与 `DbContext` 解耦，使用者无需关心连接。

---

## BeanPropertyRowMapper：结果集自动映射

这个类实现了一个轻量级的 ORM 映射逻辑。它根据 JDBC 返回的 `ResultSet` 字段，自动匹配 Java Bean 的属性并注入值，实现对象-关系映射：

```java
public class User {
    private Integer id;
    private String name;
}
```

通过反射完成映射，无需手动解析 ResultSet。

**设计亮点**：

* 利用反射技术，提高代码复用；
* 遵循 JavaBean 命名规范，便于扩展；
* 可替换为更复杂的 ORM 实现，如 MyBatis。

---

# 数据访问示例

## 原生 SQL 查询

* 保留原生 SQL 的控制力
* 支持条件拼接、动态查询、分页等复杂需求
* 设计灵活，可配合事务控制使用

```java
public class EmployeeService {
    public Employee getEmployee(int id) throws Exception {
        try(DbContext db = DbConnManager.createAppDb("test")) {
           CPQuery query = db.CPQuery().create("SELECT * FROM employees WHERE id = ?", new Object[]{id});
           return query.toSingle(Employee.class); 
        }
    }

    public int update(User user) {
        return CPQueryFactory.create()
            .sql("UPDATE user SET name = ? WHERE id = ?")
            .params(user.getName(), user.getId())
            .update();
    }
}
```

整个过程无需编写冗余的 JDBC 模板代码，调用逻辑清晰直观。

---
## 基于实体的 CRUD 操作
Javelin 框架的 DAL 设计支持基于实体的 CRUD 操作，包括：
* 实体类定义与表结构映射
* 基于实体的查询构造器
* 统一的 CRUD 操作接口
```java
public class EmployeeService {
    public void create(Employee emp) throws Exception {
        try(DbContext db = DbConnManager.createAppDb("test")) {
            db.Entity().create(Employee.class).insert(emp);
        }
    }

    public int update(@FromBody Employee employee) throws Exception {
        try(DbContext db = DbConnManager.createAppDb("test")) {
            return db.Entity().create(Employee.class).update(employee);
        }
    }

    public Employee getById(@FromRoute int id) throws Exception {
        return employeeService.getEmployeeEntity(id);
    }

    public int delete(@FromRoute int id) throws Exception {
        try(DbContext db = DbConnManager.createAppDb("test")) {
            return db.Entity().create(Employee.class).delete(id);
        }
    }

}
```

## 链式查询与条件拼接


* 支持 `.where(...)`、`.andWhere(...)` 等链式查询
* 通过注解映射自动完成字段匹配

这种“类 Repository”风格的设计让每个实体的访问操作集中在一起，符合“按实体聚合 DAL 行为”的设计理念。虽然 Javelin 目前没有实现类似 Spring Data 的 Repository 自动代理机制，但通过 `EntityFactory` 创建出的 `Entity<T>` 实例，已经具备了类似的功能：

* 用户无需手写 CRUD 实现，只需定义好实体类（如 User、Order）
* 通过链式 API 即可完成查询、插入、更新、删除操作

```java
public class EmployeeService {
    public List<Employee> list() throws Exception {
        try(DbContext db = DbConnManager.createAppDb("test")) {
            return db.Entity().create(Employee.class)
              .where("age >?", 18)
              .andWhere("name like?", "%张%")
              .orderBy("create_time desc")
        }
    }
}
```
因此，即便未实现自动代理机制，Javelin 仍然实现了 Repository 模式的核心价值：简洁、统一、按需调用。


未来也可加入如下 DSL 风格支持：

```java
.where(e -> e.getAge() > 18)
.and(e -> e.getName().contains("张"))
```
---

# 总结与展望

通过本篇文章，我们构建了一个结构清晰、职责明确、支持类 LINQ 查询与原生 SQL 混用的微型 ORM 模块，涵盖：

* 数据上下文（DbContext）
* 注解驱动实体映射
* 类 LINQ 查询接口
* 原生 SQL 兼容查询器（CPQuery）

下一篇文章中，我们将继续拓展对事务、Repository 模式以及自动代理注册的支持，进一步增强框架的工程化能力。

敬请期待。
