-- Таблица Peers
--  -Ник пира
--  -День рождения
CREATE TABLE IF NOT EXISTS Peers
(
    Nickname varchar not null primary key,
    Birthday date not null default '2000-01-01'
);

CREATE OR REPLACE PROCEDURE export_peers_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/peers.csv';
        statement varchar = 'COPY Peers TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_peers_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/peers.csv';
        statement varchar = 'COPY Peers FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Peers values ('phoenix', '2005-05-01');
insert into Peers values ('dragon', '2001-01-01');
insert into Peers values ('mermaid', '2001-10-01');
insert into Peers values ('unicorn', '2004-12-01');
insert into Peers values ('griffin', '2002-04-01');

CALL export_peers_to_csv('!');
CALL import_peers_to_csv('!');

-- Таблица Tasks
--  -Название задания
--  -Название задания, являющегося условием входа
--  -Максимальное количество XP
-- Чтобы получить доступ к заданию, нужно выполнить
-- задание, являющееся его условием входа.
-- Для упрощения будем считать, что у каждого задания
-- всего одно условие входа. В таблице должно быть одно задание,
-- у которого нет условия входа (т.е. поле ParentTask равно null).
CREATE TABLE IF NOT EXISTS Tasks
(
    Title varchar NOT NULL primary key,
    ParentTask varchar REFERENCES Tasks(Title) NULL,
    MaxXP bigint not null default 0,
    CONSTRAINT fk_Tasks_ParentTask FOREIGN KEY (ParentTask) REFERENCES Tasks(title)
);

CREATE OR REPLACE PROCEDURE export_tasks_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/tasks.csv';
        statement varchar = 'COPY Tasks TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_tasks_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/tasks.csv';
        statement varchar = 'COPY Tasks FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Tasks values ('CPP1_s21_matrix+', null, 300);
insert into Tasks values ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350);
insert into Tasks values ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600);
insert into Tasks values ('CPP4_3DViewer_v2.0', 'CPP3_SmartCalc_v2.0', 750);
insert into Tasks values ('CPP7_MLP', 'CPP4_3DViewer_v2.0', 700);

CALL export_tasks_to_csv('!');
CALL import_tasks_to_csv('!');

-- Статус проверки
-- Создать тип перечисления для статуса проверки,
-- содержащий следующие значения:
--
-- Start - начало проверки
-- Success - успешное окончание проверки
-- Failure - неудачное окончание проверки
CREATE TYPE state AS ENUM ('Start', 'Success', 'Failure');

-- Таблица P2P
--  -ID
--  -ID проверки
--  -Ник проверяющего пира
--  -Статус P2P проверки
--  -Время
-- Каждая P2P проверка состоит из 2-х записей в таблице:
-- первая имеет статус начало, вторая - успех или неуспех.
-- В таблице не может быть больше одной незавершенной P2P проверки,
-- относящейся к конкретному заданию, пиру и проверяющему.
-- Каждая P2P проверка (т.е. обе записи, из которых она состоит)
-- ссылается на проверку в таблице Checks, к которой она относится.
CREATE TABLE IF NOT EXISTS P2P
(
    ID serial primary key not null,
    "Check" bigint not null REFERENCES Checks(ID),
    CheckingPeer varchar not null REFERENCES Peers(Nickname),
    State state not null,
    "Time" time not null default '00:00'
--     constraint fk_P2P_Check foreign key ("Check") references Checks(ID)
--     constraint fk_P2P_CheckingPeer foreign key (CheckingPeer) references Peers(Nickname),
--     constraint ch_CheckCount CHECK ( count("Check") <= 2 )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unfinished_check ON P2P("Check", CheckingPeer, State)
WHERE State = 'Start' AND (SELECT count(Task) FROM Checks c WHERE Peer = CheckingPeer AND "Check" = c.ID);

CREATE OR REPLACE PROCEDURE export_p2p_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/p2p.csv';
        statement varchar = 'COPY P2P TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_p2p_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/p2p.csv';
        statement varchar = 'COPY P2P FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into P2P values (1, 1, 'phoenix', 'Start', '01:30');
insert into P2P values (2, 1, 'phoenix', 'Success', '02:00');
insert into P2P values (3, 2, 'dragon', 'Start', '11:00');
insert into P2P values (4, 2, 'dragon', 'Failure', '11:20');
insert into P2P values (5, 3, 'griffin', 'Start', '11:00');
insert into P2P values (6, 3, 'griffin', 'Success', '11:20');


-- Таблица Verter
--  -ID
--  -ID проверки
--  -Статус проверки Verter'ом
--  -Время
-- Каждая проверка Verter'ом состоит из 2-х записей в таблице:
-- первая имеет статус начало, вторая - успех или неуспех.
-- Каждая проверка Verter'ом (т.е. обе записи, из которых она состоит)
-- ссылается на проверку в таблице Checks, к которой она относится.
-- Проверка Verter'ом может ссылаться только на те проверки в таблице
-- Checks, которые уже включают в себя успешную P2P проверку.
CREATE TABLE IF NOT EXISTS Verter
(
    ID serial primary key not null,
    "Check" bigint not null REFERENCES Checks(ID),
    State state not null,
    "Time" time not null default '00:00'
--     constraint fk_Verter_Check foreign key ("Check") references Checks(ID)
);

CREATE OR REPLACE PROCEDURE export_verter_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/verter.csv';
        statement varchar = 'COPY Verter TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_verter_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/verter.csv';
        statement varchar = 'COPY Verter FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Verter values (1, 1, 'Start', '02:00');
insert into Verter values (2, 1, 'Success', '02:05');
insert into Verter values (3, 2, 'Start', '11:20');
insert into Verter values (4, 2, 'Success', '11:25');
insert into Verter values (5, 3, 'Start', '11:20');
insert into Verter values (6, 3, 'Success', '11:25');

-- Таблица Checks
--  -ID
--  -Ник пира
--  -Название задания
--  -Дата проверки
-- Описывает проверку задания в целом. Проверка обязательно включает в
-- себя один этап P2P и, возможно, этап Verter. Для упрощения будем
-- считать, что пир ту пир и автотесты, относящиеся к одной проверке,
-- всегда происходят в один день.
--
-- Проверка считается успешной, если соответствующий P2P этап успешен,
-- а этап Verter успешен, либо отсутствует. Проверка считается неуспешной,
-- хоть один из этапов неуспешен. То есть проверки, в которых
-- ещё не завершился этап P2P, или этап P2P успешен, но ещё не завершился
-- этап Verter, не относятся ни к успешным, ни к неуспешным.
CREATE TABLE IF NOT EXISTS Checks
(
    ID serial primary key not null,
    Peer varchar not null REFERENCES Peers(Nickname),
    Task varchar not null REFERENCES Tasks(Title),
    "Date" date not null default '2022-01-01'
--     constraint fk_Checks_Peer foreign key (Peer) references Peers(Nickname),
--     constraint fk_Checks_Task foreign key (Task) references Tasks(Title)
);

CREATE OR REPLACE PROCEDURE export_checks_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/checks.csv';
        statement varchar = 'COPY Checks TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_checks_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/checks.csv';
        statement varchar = 'COPY Checks FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Checks values (1, 'mermaid', 'CPP1_s21_matrix+', '2021-09-10');
insert into Checks values (2, 'unicorn', 'CPP3_SmartCalc_v2.0', '2022-10-01');
insert into Checks values (3, 'dragon', 'CPP1_s21_matrix+', '2021-09-12');
insert into Checks values (4, 'phoenix', 'CPP7_MLP', '2022-01-01');
insert into Checks values (5, 'dragon', 'CPP2_s21_containers', '2022-01-11');



-- insert into Checks (Peer, Task, "Date") values (1, 'dragon', 'CPP7_MLP', '2022-01-01');

-- Таблица TransferredPoints
--  -ID
--  -Ник проверяющего пира
--  -Ник проверяемого пира
--  -Количество переданных пир поинтов за всё время (только от проверяемого к
--  проверяющему)
-- При каждой P2P проверке проверяемый пир передаёт один пир поинт
-- проверяющему. Эта таблица содержит все пары проверяемый-проверяющий
-- и кол-во переданных пир поинтов, то есть, другими словами,
-- количество P2P проверок указанного проверяемого пира, данным
-- проверяющим.
CREATE TABLE IF NOT EXISTS TransferredPoints
(
    ID serial primary key not null,
    CheckingPeer varchar not null REFERENCES Peers(nickname),
    CheckedPeer varchar not null REFERENCES Peers(nickname),
    PointsAmount bigint not null default 0
--     constraint fk_TransferredPoints_CheckingPeer foreign key (CheckingPeer) references Peers(Nickname),
--     constraint fk_TransferredPoints_CheckedPeer foreign key (CheckedPeer) references Peers(Nickname)
);

CREATE OR REPLACE PROCEDURE export_transferredpoints_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/peetransferredpointsrs.csv';
        statement varchar = 'COPY TransferredPoints TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_transferredpoints_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/transferredpoints.csv';
        statement varchar = 'COPY TransferredPoints FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into TransferredPoints values (1, 'phoenix', 'dragon', 1);
insert into TransferredPoints values (2, 'dragon', 'unicorn', 1);
insert into TransferredPoints values (1, 'mermaid', 'dragon', 2);
insert into TransferredPoints values (2, 'unicorn', 'griffin', 1);
insert into TransferredPoints values (1, 'griffin', 'dragon', 3);

-- Таблица Friends
--  -ID
--  -Ник первого пира
--  -Ник второго пира
-- Дружба взаимная, т.е. первый пир является другом второго, а
-- второй -- другом первого.
CREATE TABLE IF NOT EXISTS Friends
(
    ID serial primary key not null,
    Peer1 varchar not null  REFERENCES Peers(nickname),
    Peer2 varchar not null  REFERENCES Peers(nickname),
    constraint fk_Friends_Peer1 foreign key (Peer1) references Peers(Nickname),
    constraint fk_Friends_Peer2 foreign key (Peer2) references Peers(Nickname)
);

CREATE OR REPLACE PROCEDURE export_friends_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/friends.csv';
        statement varchar = 'COPY Friends TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_friends_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/friends.csv';
        statement varchar = 'COPY Friends FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Friends values (1, 'phoenix', 'dragon');
insert into Friends values (2, 'unicorn', 'phoenix');
insert into Friends values (3, 'mermaid', 'dragon');
insert into Friends values (4, 'phoenix', 'unicorn');
insert into Friends values (5, 'griffin', 'unicorn');

-- Таблица Recommendations
--  -ID
--  -Ник пира
--  -Ник пира, к которому рекомендуют идти на проверку
-- Каждому может понравиться, как проходила P2P проверка у того или
-- иного пира. Пир, указанный в поле Peer, рекомендует проходить P2P
-- проверку у пира из поля RecomendedPeer. Каждый пир может рекомендовать
-- как ни одного, так и сразу несколько проверяющих.
CREATE TABLE IF NOT EXISTS Recommendations
(
    ID serial primary key not null,
    Peer varchar not null  REFERENCES Peers(nickname),
    RecommendedPeer varchar not null  REFERENCES Peers(nickname),
    constraint fk_Recommendations_Peer foreign key (Peer) references Peers(Nickname),
    constraint fk_Recommendations_RecommendedPeer foreign key (RecommendedPeer) references Peers(Nickname)
);

CREATE OR REPLACE PROCEDURE export_recommendations_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/recommendations.csv';
        statement varchar = 'COPY Recommendations TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_recommendations_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/recommendations.csv';
        statement varchar = 'COPY Recommendations FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into Recommendations values (1, 'dragon', 'phoenix');
insert into Recommendations values (2, 'phoenix', 'unicorn');
insert into Recommendations values (3, 'griffin', 'mermaid');
insert into Recommendations values (4, 'unicorn', 'dragon');
insert into Recommendations values (5, 'dragon', 'griffin');

-- Таблица XP
--  -ID
--  -ID проверки
--  -Количество полученного XP
-- За каждую успешную проверку пир, выполнивший задание, получает какое-то
-- количество XP, отображаемое в этой таблице. Количество XP не может
-- превышать максимальное доступное для проверяемой задачи. Первое поле
-- этой таблицы может ссылаться только на успешные проверки.
CREATE TABLE IF NOT EXISTS XP
(
    ID serial primary key not null,
    "Check" bigint not null REFERENCES Checks(ID),
    XPAmount bigint not null default 0
--     constraint fk_XP_Check foreign key ("Check") references Checks(ID)
);

CREATE OR REPLACE PROCEDURE export_xp_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/xp.csv';
        statement varchar = 'COPY XP TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_xp_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/xp.csv';
        statement varchar = 'COPY XP FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into XP values (1, 1, 750);
insert into XP values (1, 1, 750);
insert into XP values (1, 1, 750);
insert into XP values (1, 1, 750);
insert into XP values (1, 1, 750);

-- Таблица TimeTracking
--  -ID
--  -Ник пира
--  -Дата
--  -Время
--  -Состояние (1 - пришел, 2 - вышел)
-- Данная таблица содержит информация о посещениях пирами кампуса.
-- Когда пир входит в кампус, в таблицу добавляется запись с состоянием 1,
-- когда покидает - с состоянием 2.
--
-- В заданиях, относящихся к этой таблице, под действием "выходить"
-- подразумеваются все покидания кампуса за день, кроме последнего.
-- В течение одного дня должно быть одинаковое количество записей с
-- состоянием 1 и состоянием 2 для каждого пира.
--
-- Например:
--
-- ID	Peer	Date	Time	State
-- 1	Aboba	22.03.22	13:37	1
-- 2	Aboba	22.03.22	15:48	2
-- 3	Aboba	22.03.22	16:02	1
-- 4	Aboba	22.03.22	20:00	2
-- В этом примере "выходом" является только запись с ID, равным 2.
-- Пир с ником Aboba выходил из кампуса на 14 минут.
CREATE TABLE IF NOT EXISTS TimeTracking
(
    ID serial primary key not null,
    Peer varchar not null  REFERENCES Peers(nickname),
    "Date" date not null default '2022-01-01',
    "Time" time not null default '00:00',
    State int CHECK (State = 1 OR State = 2)
--     constraint fk_TimeTracking_Peer foreign key (Peer) references Peers(Nickname)
);

CREATE OR REPLACE PROCEDURE export_timetracking_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/timetracking.csv';
        statement varchar = 'COPY TimeTracking TO '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        execute statement;
    end
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_timetracking_to_csv(Separator CHAR(1) default ',') AS
$$
    DECLARE
        path varchar = '/tmp/timetracking.csv';
        statement varchar = 'COPY TimeTracking FROM '''|| path ||''' With DELIMITER '''|| Separator ||''' CSV HEADER;';
    begin
        EXECUTE statement;
    end
$$ LANGUAGE plpgsql;

insert into TimeTracking values (1, 'dragon', '2022-01-01', '01:00', 1);
insert into TimeTracking values (2, 'dragon', '2022-01-01', '07:00', 2);
insert into TimeTracking values (3, 'phoenix', '2022-01-01', '00:00', 1);
insert into TimeTracking values (4, 'phoenix', '2022-01-01', '03:00', 2);
insert into TimeTracking values (5, 'phoenix', '2022-01-02', '01:00', 1);
insert into TimeTracking values (6, 'phoenix', '2022-01-02', '07:00', 2);

-- Также внесите в скрипт процедуры, позволяющие импортировать и экспортировать данные
-- для каждой таблицы из файла/в файл с расширением .csv.
-- В качестве параметра каждой процедуры указывается разделитель csv файла.
--
-- В каждую из таблиц внесите как минимум по 5 записей. По мере выполнения задания вам
-- потребуются новые данные, чтобы проверить все варианты работы. Эти новые данные также
-- должны быть добавлены в этом скрипте.
--
-- Если для добавления данных в таблицы использовались csv файлы, они также должны быть
-- выгружены в GIT репозиторий.
--
-- *Все задания должны быть названы в формате названий для Школы 21, например A5_s21_memory.
-- В дальнейшем принадлежность к блоку будет определяться по содержанию в названии задания
-- названия блока, например "CPP3_SmartCalc_v2.0" принадлежит блоку CPP. \*

-- select * from Tasks;