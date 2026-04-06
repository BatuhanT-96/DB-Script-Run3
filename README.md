# DB Script Dispatcher - Controlled GitLab CI/CD SQL Execution

Bu repository, **manual tetiklenen GitLab pipeline** üzerinden Oracle ve PostgreSQL scriptlerinin kontrollü, güvenli ve izlenebilir şekilde çalıştırılması için tasarlanmıştır.

## 1) Projenin Amacı

Amaç, kullanıcıların sadece aşağıdaki pipeline değişkenlerini girerek doğru SQL dosyasını doğru ortama ve doğru DB tipine çalıştırmasını sağlamaktır:

- `DB_TYPE` (`Oracle` | `Postgre`)
- `ENVIRONMENT` (`Test` | `Prod`)
- `DB_NAME` (manuel)
- `SCRIPT_TYPE` (`DDL` | `DML`)
- `SCRIPT_NAME` (manuel, yalnızca dosya adı)

Sistem; input validation, güvenli path çözümleme, Postgre schema kontrolü, Prod destructive komut engelleme ve Prod approval gate ile çalışır.

## 2) Mimari Yaklaşım

Pipeline aşamaları:

1. **validate**
   - Input validation
   - Güvenli SQL dosya çözümleme
   - Prod safety validation (Prod ise)
   - Postgre schema qualification validation (DB_TYPE=Postgre ise)
2. **approve**
   - Prod için manuel onay (protected environment ile entegre olacak şekilde)
3. **execute**
   - DB tipine göre güvenli çalıştırma (`psql` veya `sqlplus`)

Pipeline yalnızca GitLab UI üzerinden **Run pipeline** ile (`CI_PIPELINE_SOURCE=web`) başlatılabilir; push/merge/api/schedule kaynakları engellenmiştir.

## 3) Dizin Yapısı (Zorunlu)

SQL scriptlerin aşağıdaki zorunlu formatta tutulması gerekir:

```text
DB-Scripts-Run/<DB_TYPE>/<ENVIRONMENT>/<SCRIPT_TYPE>/<DB_NAME>/<SCRIPT_NAME>
```

Örnek:

- `DB-Scripts-Run/Postgre/Test/DML/mydb/sample_update_.sql`
- `DB-Scripts-Run/Oracle/Prod/DDL/crmdb/add_index.sql`

Bu yapı dışında dosya çözümü yapılmaz.

## 4) Repository Yapısı

```text
.
├── .gitlab-ci.yml
├── README.md
├── scripts/
│   ├── common.sh
│   ├── validate_inputs.sh
│   ├── resolve_connection.sh
│   ├── validate_postgres_schema.py
│   ├── validate_prod_safety.py
│   ├── execute_postgres.sh
│   ├── execute_oracle.sh
│   └── resolve_sql_file.sh
└── DB-Scripts-Run/
    ├── Oracle/
    │   ├── Test/
    │   │   ├── DDL/crmdb/
    │   │   └── DML/crmdb/
    │   └── Prod/
    │       ├── DDL/crmdb/
    │       └── DML/crmdb/
    └── Postgre/
        ├── Test/
        │   ├── DDL/mydb/
        │   └── DML/mydb/
        └── Prod/
            ├── DDL/mydb/
            └── DML/mydb/
```

## 5) Pipeline Variables

Pipeline başlangıcında kullanıcıya gösterilecek değişkenler:

- `DB_TYPE`: `Oracle` veya `Postgre`
- `ENVIRONMENT`: `Test` veya `Prod`
- `SCRIPT_TYPE`: `DDL` veya `DML`
- `DB_NAME`: güvenli karakter seti ile sınırlı (`[A-Za-z0-9_-]+`)
- `SCRIPT_NAME`: yalnızca dosya adı, `.sql` uzantılı

> Not: GitLab sürümüne göre dropdown/options desteği sınırlı olabilir. Bu nedenle asıl güvenlik script tabanlı validation ile sağlanır.

## 6) GitLab Secret Variable Tanımları

### Postgre

- `POSTGRE_TEST_HOST`
- `POSTGRE_TEST_PORT`
- `POSTGRE_TEST_USER`
- `POSTGRE_TEST_PASSWORD`
- `POSTGRE_PROD_HOST`
- `POSTGRE_PROD_PORT`
- `POSTGRE_PROD_USER`
- `POSTGRE_PROD_PASSWORD`

### Oracle

- `ORACLE_TEST_HOST`
- `ORACLE_TEST_PORT`
- `ORACLE_TEST_USER`
- `ORACLE_TEST_PASSWORD`
- `ORACLE_PROD_HOST`
- `ORACLE_PROD_PORT`
- `ORACLE_PROD_USER`
- `ORACLE_PROD_PASSWORD`

### Oracle Service/SID (Opsiyonel ama önerilir)

- `ORACLE_TEST_SERVICE_NAME` veya `ORACLE_TEST_SID`
- `ORACLE_PROD_SERVICE_NAME` veya `ORACLE_PROD_SID`

Kural:
- Aynı anda `SERVICE_NAME` ve `SID` verilmez.
- İkisi de verilmezse fallback olarak `DB_NAME` service name kabul edilir (`//host:port/DB_NAME`).

## 7) Validation Akışı

### 7.1 Input Validation

- `DB_TYPE` sadece `Oracle|Postgre`
- `ENVIRONMENT` sadece `Test|Prod`
- `SCRIPT_TYPE` sadece `DDL|DML`
- `DB_NAME` regex + traversal koruması
- `SCRIPT_NAME` sadece dosya adı, slash yok, `..` yok, `.sql` zorunlu

### 7.2 Güvenli SQL File Resolution

Dosya yolu derive edilir:

```text
DB-Scripts-Run/${DB_TYPE}/${ENVIRONMENT}/${SCRIPT_TYPE}/${DB_NAME}/${SCRIPT_NAME}
```

Sonra:

- canonical path kontrolü
- root dışına çıkış engeli
- dosya var mı kontrolü
- regular file kontrolü
- symlink reddi
- uzantı kontrolü

### 7.3 Postgre Schema Validation

`DB_TYPE=Postgre` olduğunda tüm dosya taranır.

Kontrol edilen ana statement türleri:

- `UPDATE`
- `INSERT INTO`
- `DELETE FROM`
- `TRUNCATE`
- `ALTER TABLE`
- `DROP TABLE`
- `CREATE TABLE`
- `CREATE INDEX`
- `DROP INDEX`
- `LOCK TABLE`
- `RENAME TABLE`

Validator yaklaşımı:

- yorumları (`--`, `/* */`) maskeler
- string literal’ları maskeler
- case-insensitive çalışır
- çok statement içeren dosyada tüm ihlalleri raporlar
- ihlalde satır numarası ile fail verir

### 7.4 Prod Safety Validation

`ENVIRONMENT=Prod` için hem Oracle hem Postgre scriptlerinde aşağıdaki pattern’ler engellenir:

- `DELETE`
- `TRUNCATE`
- `DROP TABLE`
- `DROP COLUMN`
- `DROP INDEX`
- `ALTER COLUMN`
- `ALTER TABLE ... DROP`
- `ALTER TABLE ... RENAME`
- `RENAME`
- `DROP` (genel)

Yorumlar/string literal maskelenir; tüm dosya taranır; ihlalde pipeline fail olur.

## 8) Approval ve Protected Environment

Prod execution öncesi `approve_prod_execution` job’ı manuel onay ister.

- Test için onay gerekmez.
- Prod için `environment: db-prod` kullanılır.
- GitLab UI > **Settings > CI/CD > Protected environments** bölümünden `db-prod` environment’ına approver/allowed deployer bağlanabilir.

Önerilen kurulum:

1. `db-prod` protected environment oluşturun.
2. Sadece yetkili grup/kullanıcılara deploy izni verin.
3. İsterseniz required approvals tanımlayın.

## 9) Execute Davranışı

### Postgre

- `psql` kullanılır
- `ON_ERROR_STOP=1` ile SQL hatasında fail-fast
- `--no-psqlrc` ile local psqlrc etkisi engellenir
- şifre log’a basılmaz, `PGPASSWORD` environment ile geçirilir

### Oracle

- `sqlplus` kullanılır
- `/nolog` + `CONNECT` + `WHENEVER SQLERROR EXIT` ile hata durumunda fail
- şifre echo edilmez

## 10) Runner Gereksinimleri

Bu yapı **Linux shell runner** varsayımıyla tasarlanmıştır.

Runner host üzerinde:

- `bash`
- `python3` (standard library yeterli)
- `psql` (Postgre çalıştırmaları için)
- `sqlplus` (Oracle çalıştırmaları için; Oracle client kurulu olmalı)
- PATH içinde erişilebilir komutlar

Ayrıca:

- runner -> DB host erişimi (network/firewall)
- DNS çözümleme
- ilgili portlara outbound izin

## 11) Örnek Kullanım

### Örnek 1

- `DB_TYPE=Postgre`
- `ENVIRONMENT=Test`
- `DB_NAME=mydb`
- `SCRIPT_TYPE=DML`
- `SCRIPT_NAME=sample_update_.sql`

Çözümlediği dosya:
`DB-Scripts-Run/Postgre/Test/DML/mydb/sample_update_.sql`

### Örnek 2

- `DB_TYPE=Oracle`
- `ENVIRONMENT=Prod`
- `DB_NAME=crmdb`
- `SCRIPT_TYPE=DDL`
- `SCRIPT_NAME=add_index.sql`

Çözümlediği dosya:
`DB-Scripts-Run/Oracle/Prod/DDL/crmdb/add_index.sql`

## 12) Validation Fail Örnekleri

1. **Schema’sız Postgre UPDATE**
   - `UPDATE locals SET value='x' WHERE id=1;`
   - Hata: schema-qualified değil.

2. **Prod’da DELETE içeren script**
   - `DELETE FROM public.logs WHERE ...`
   - Hata: destructive komut.

3. **Yanlış SCRIPT_NAME**
   - `SCRIPT_NAME=../../etc/passwd`
   - Hata: karakter ve traversal validation.

4. **Eksik GitLab variable**
   - Örn. `POSTGRE_PROD_PASSWORD` eksik
   - Hata: ilgili variable adı ile fail.

## 13) Troubleshooting

- `Required command not found`: Runner PATH veya paket kurulumu eksik.
- `SQL file not found`: Dizin yapısı veya variable değerleri yanlış.
- `escapes allowed root`: path traversal/symlink kontrolüne takıldı.
- `schema validation failed`: Postgre scriptte schema prefix eksik.
- `Prod safety validation failed`: Prod için yasaklı komut var.
- `Required variable is missing`: GitLab CI/CD variable tanımı eksik.

## 14) Güvenlik Notları

- Secret değerleri log’a yazılmaz.
- `set -x` kullanılmaz.
- Password echo edilmez.
- Path traversal ve symlink abuse engellenir.
- Pipeline sadece doğrulanmış ve zorunlu dizin yapısına uyan dosyaları çalıştırır.
- Prod için hem teknik validation hem manuel approval gate vardır.

## 15) Genişletme (Yeni DB Tipi Ekleme)

Yeni bir DB eklenecekse:

1. `validate_inputs.sh` enum listesine ekleyin.
2. `resolve_connection.sh` içine yeni prefix mapping ekleyin.
3. Yeni `execute_<db>.sh` dosyası ekleyin.
4. `.gitlab-ci.yml` execute dispatch bölümüne yeni koşul ekleyin.
5. İlgili DB için validation scripti gerekiyorsa yeni validator ekleyin.
6. README variable ve güvenlik kurallarını güncelleyin.

Bu yaklaşım merkezi mapping + ayrık execution scriptleri sayesinde bakım kolaylığı sağlar.
