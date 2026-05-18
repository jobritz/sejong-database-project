-- #############################################
-- #                   Pre Setup               #
-- #############################################
USE master;
GO

-- logins
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_customer')
    CREATE LOGIN demo_customer 
    WITH PASSWORD = 'YourStrongPassword', 
         CHECK_POLICY = ON, 
         CHECK_EXPIRATION = OFF;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'hotel_staff')
    CREATE LOGIN hotel_staff 
    WITH PASSWORD = 'YourStrongPassword', 
         CHECK_POLICY = ON, 
         CHECK_EXPIRATION = OFF;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'system_admin')
    CREATE LOGIN system_admin 
    WITH PASSWORD = 'YourStrongPassword', 
         CHECK_POLICY = ON, 
         CHECK_EXPIRATION = OFF;

-- new database
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'HotelBookingSystemDB')
    CREATE DATABASE HotelBookingSystemDB;
GO

USE HotelBookingSystemDB;
GO

-- #############################################
-- #  Data definition language (CREATE TABLE)  #
-- #############################################

-- address table
CREATE TABLE address (
    internal_ID     INT IDENTITY(1,1) NOT NULL,
    address_ID      AS 'ADR' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    country         VARCHAR(60)  NOT NULL,
    city            VARCHAR(200) NOT NULL,
    district        VARCHAR(50),
    streetAddress   VARCHAR(100) NOT NULL,
    PRIMARY KEY (address_ID)
);
GO

-- customer table
CREATE TABLE customer (
    internal_ID  INT IDENTITY(1,1) NOT NULL,
    customer_ID  AS 'CUS' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    firstName    VARCHAR(50)  NOT NULL,
    lastName     VARCHAR(50)  NOT NULL,
    phoneNumber  VARCHAR(20)  NOT NULL,
    email        VARCHAR(254) NOT NULL,
    address_ID   VARCHAR(8),
    UNIQUE (email),
    PRIMARY KEY (customer_ID),
    FOREIGN KEY (address_ID) REFERENCES address(address_ID) ON DELETE SET NULL ON UPDATE CASCADE
);
GO

-- hotel table
CREATE TABLE hotel (
    internal_ID  INT IDENTITY(1,1) NOT NULL,
    hotel_ID     AS 'HTL' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    hotelName    VARCHAR(100) NOT NULL,
    phoneNumber  VARCHAR(20)  NOT NULL,
    email        VARCHAR(254) NOT NULL,
    address_ID   VARCHAR(8),
    UNIQUE (email, address_ID),
    PRIMARY KEY (hotel_ID),
    FOREIGN KEY (address_ID) REFERENCES address(address_ID) ON DELETE SET NULL ON UPDATE CASCADE
);
GO

-- roomCategory table
CREATE TABLE roomCategory (
    internal_ID      INT IDENTITY(1,1) NOT NULL,
    roomCategory_ID  AS 'RCT' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    categoryTitle    VARCHAR(100)   NOT NULL,
    hotel_ID         VARCHAR(8)     NOT NULL,
    price            DECIMAL(8,2)   NOT NULL CHECK (price >= 0),
    maxGuests        SMALLINT       NOT NULL CHECK (maxGuests > 0),
    size             SMALLINT       NOT NULL CHECK (size > 0),
    PRIMARY KEY (roomCategory_ID),
    FOREIGN KEY (hotel_ID) REFERENCES hotel(hotel_ID) ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- room table
CREATE TABLE room (
    hotel_ID         VARCHAR(8) NOT NULL,
    roomNumber       VARCHAR(7) NOT NULL,
    roomCategory_ID  VARCHAR(8),
    floor            VARCHAR(3) NOT NULL,
    PRIMARY KEY (hotel_ID, roomNumber),
    FOREIGN KEY (hotel_ID)        REFERENCES hotel(hotel_ID)               ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (roomCategory_ID) REFERENCES roomCategory(roomCategory_ID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- reservation table
CREATE TABLE reservation (
    internal_ID     INT IDENTITY(1,1) NOT NULL,
    reservation_ID  AS 'RES' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    customer_ID     VARCHAR(8) NOT NULL,
    checkin         DATETIME   NOT NULL,
    checkout        DATETIME   NOT NULL,
    guests          SMALLINT   NOT NULL CHECK (guests > 0),
    status          CHAR(1)    NOT NULL CHECK (status IN ('R', 'C', 'P')) DEFAULT 'R',
    CONSTRAINT check_dates CHECK (checkin < checkout),
    PRIMARY KEY (reservation_ID),
    FOREIGN KEY (customer_ID) REFERENCES customer(customer_ID) ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- invoice table
CREATE TABLE invoice (
    reservation_ID  VARCHAR(8)    NOT NULL,
    totalPrice      DECIMAL(10,2),
    invoiceDate     DATE          NOT NULL DEFAULT GETDATE(),
    address_ID      VARCHAR(8),
    PRIMARY KEY (reservation_ID),
    FOREIGN KEY (address_ID)     REFERENCES address(address_ID)         ON DELETE NO ACTION ON UPDATE NO ACTION,
    FOREIGN KEY (reservation_ID) REFERENCES reservation(reservation_ID) ON DELETE CASCADE   ON UPDATE CASCADE
);
GO

-- room_reservation table
CREATE TABLE room_reservation (
    hotel_ID        VARCHAR(8) NOT NULL,
    roomNumber      VARCHAR(7) NOT NULL,
    reservation_ID  VARCHAR(8) NOT NULL,
    PRIMARY KEY (hotel_ID, roomNumber, reservation_ID),
    FOREIGN KEY (hotel_ID, roomNumber) REFERENCES room(hotel_ID, roomNumber)        ON DELETE CASCADE   ON UPDATE CASCADE,
    FOREIGN KEY (reservation_ID)       REFERENCES reservation(reservation_ID)       ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- equipment table
CREATE TABLE equipment (
    internal_ID     INT IDENTITY(1,1) NOT NULL,
    equipment_ID    AS 'EQP' + RIGHT('00000' + CAST(internal_ID AS VARCHAR(5)), 5) PERSISTED,
    equipmentTitle  VARCHAR(100) NOT NULL,
    PRIMARY KEY (equipment_ID)
);
GO

-- roomCategory_equipment table
CREATE TABLE roomCategory_equipment (
    roomCategory_ID  VARCHAR(8) NOT NULL,
    equipment_ID     VARCHAR(8) NOT NULL,
    amount           SMALLINT   NOT NULL CHECK (amount > 0) DEFAULT 1,
    PRIMARY KEY (roomCategory_ID, equipment_ID),
    FOREIGN KEY (roomCategory_ID) REFERENCES roomCategory(roomCategory_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (equipment_ID)    REFERENCES equipment(equipment_ID)       ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- additionalOption table
CREATE TABLE additionalOption (
    additionalOptionTitle  VARCHAR(100) NOT NULL,
    hotel_ID               VARCHAR(8)   NOT NULL,
    price                  DECIMAL(8,2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (additionalOptionTitle, hotel_ID),
    FOREIGN KEY (hotel_ID) REFERENCES hotel(hotel_ID) ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- reservation_additionalOption table
CREATE TABLE reservation_additionalOption (
    additionalOptionTitle  VARCHAR(100) NOT NULL,
    hotel_ID               VARCHAR(8)   NOT NULL,
    reservation_ID         VARCHAR(8)   NOT NULL,
    amount                 SMALLINT     NOT NULL CHECK (amount > 0) DEFAULT 1,
    PRIMARY KEY (additionalOptionTitle, hotel_ID, reservation_ID),
    FOREIGN KEY (additionalOptionTitle, hotel_ID) REFERENCES additionalOption(additionalOptionTitle, hotel_ID) ON DELETE CASCADE   ON UPDATE CASCADE,
    FOREIGN KEY (reservation_ID)                  REFERENCES reservation(reservation_ID)                      ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO


-- #############################################
-- #             Data Insertion                #
-- #############################################

-- addresses
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Berlin','Mitte','Alexanderplatz 1');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Munich','Altstadt','Marienplatz 5');
INSERT INTO address (country, city, district, streetAddress) VALUES ('France','Paris','1er','Rue de Rivoli 10');
INSERT INTO address (country, city, district, streetAddress) VALUES ('United Kingdom','London','Westminster','10 Downing St');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Spain','Barcelona','Eixample','Passeig de Gracia 20');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Rome','Centro','Via Veneto 12');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Netherlands','Amsterdam','Centrum','Damrak 2');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Austria','Vienna','Innere Stadt','Kärntner Strasse 1');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Switzerland','Zurich','Altstadt','Bahnhofstrasse 8');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Portugal','Lisbon','Baixa','Rua Augusta 15');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Belgium','Brussels','Pentagon','Grand Place 3');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Sweden','Stockholm','Norrmalm','Drottninggatan 30');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Denmark','Copenhagen','Indre By','Strøget 7');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Norway','Oslo','Sentrum','Karl Johans gate 10');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Finland','Helsinki','Keskusta','Esplanadi 21');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Poland','Warsaw','Śródmieście','Nowy Świat 25');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Czech Republic','Prague','Staré Město','Karlova 4');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Greece','Athens','Plaka','Adrianou 9');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Ireland','Dublin','City Centre','Grafton St 11');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Hungary','Budapest','V. kerület','Váci utca 6');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Jongno-gu','Insadong 12');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Gangnam-gu','Teheran-ro 45');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Mapo-gu','Hongdae 3');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Yongsan-gu','Itaewon 8');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Jung-gu','Myeongdong 2');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Seocho-gu','Banpo-daero 20');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Songpa-gu','Jamsil 6');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Dongdaemun-gu','Cheonggyecheon 1');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Eunpyeong-gu','Sinsa 9');
INSERT INTO address (country, city, district, streetAddress) VALUES ('South Korea','Seoul','Nowon-gu','Sanggye 4');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Milan','Centro Storico','Via Montenapoleone 8');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Florence','Oltrarno','Via Maggio 14');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Venice','San Marco','Calle Larga 3');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Naples','Spaccanapoli','Via Toledo 22');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Turin','Centro','Via Roma 17');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Bologna','Quadrilatero','Via Indipendenza 5');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Italy','Verona','Città Antica','Via Mazzini 11');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Hamburg','Altstadt','Jungfernstieg 6');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Frankfurt','Innenstadt','Zeil 33');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Cologne','Altstadt-Nord','Hohe Straße 12');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Stuttgart','Mitte','Königstraße 19');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Düsseldorf','Stadtmitte','Königsallee 28');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Dresden','Innere Altstadt','Prager Straße 7');
INSERT INTO address (country, city, district, streetAddress) VALUES ('Germany','Leipzig','Zentrum','Grimmaische Straße 4');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','New York','Manhattan','5th Avenue 350');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','Los Angeles','Downtown','Wilshire Blvd 500');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','Chicago','The Loop','Michigan Avenue 233');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','San Francisco','Union Square','Market Street 101');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','Miami','Brickell','Biscayne Blvd 1200');
INSERT INTO address (country, city, district, streetAddress) VALUES ('USA','Boston','Back Bay','Boylston Street 88');
GO

-- hotels
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Central Berlin Hotel','+49-30-1111111','berlin1@hotels.example','ADR00001');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Munich City Inn','+49-89-2222222','munich@hotels.example','ADR00002');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Paris Grand','+33-1-3333333','paris@hotels.example','ADR00003');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('London Bridge Hotel','+44-20-4444444','london@hotels.example','ADR00004');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Barcelona Suites','+34-93-5555555','barca@hotels.example','ADR00005');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Rome Palace','+39-06-6666666','rome@hotels.example','ADR00006');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Amsterdam Canal Hotel','+31-20-7777777','amsterdam@hotels.example','ADR00007');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Vienna Comfort','+43-1-8888888','vienna@hotels.example','ADR00008');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Zurich Lakeview','+41-44-9999999','zurich@hotels.example','ADR00009');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Lisbon Harbor','+351-21-1010101','lisbon@hotels.example','ADR00010');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Brussels Royal','+32-2-1112222','brussels@hotels.example','ADR00011');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Stockholm Nordic','+46-8-3334444','stockholm@hotels.example','ADR00012');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Copenhagen Harbor','+45-33-555666','copenhagen@hotels.example','ADR00013');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Oslo Fjord Hotel','+47-22-777888','oslo@hotels.example','ADR00014');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Helsinki Central','+358-9-1212121','helsinki@hotels.example','ADR00015');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Warsaw Old Town','+48-22-1313131','warsaw@hotels.example','ADR00016');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Prague Castle Inn','+420-2-1414141','prague@hotels.example','ADR00017');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Athens View','+30-21-1515151','athens@hotels.example','ADR00018');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Dublin Gate','+353-1-1616161','dublin@hotels.example','ADR00019');
INSERT INTO hotel (hotelName, phoneNumber, email, address_ID) VALUES ('Budapest Danube','+36-1-1717171','budapest@hotels.example','ADR00020');
GO

-- customers
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Min','Kim','+82-10-00000001','min.kim1@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Jin','Lee','+82-10-00000002','jin.lee2@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Soo','Park','+82-10-00000003','soo.park3@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Hana','Choi','+82-10-00000004','hana.choi4@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Jae','Yoon','+82-10-00000005','jae.yoon5@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Eun','Kang','+82-10-00000006','eun.kang6@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Dae','Lim','+82-10-00000007','dae.lim7@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Young','Han','+82-10-00000008','young.han8@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Seo','Oh','+82-10-00000009','seo.oh9@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Hye','Lim','+82-10-00000010','hye.lim10@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Alex','Müller','+49-170-0000011','alex.mueller11@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Maria','Schmidt','+49-170-0000012','maria.schmidt12@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Luca','Rossi','+39-320-0000013','luca.rossi13@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Sofia','Garcia','+34-600-0000014','sofia.garcia14@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Noah','Smith','+44-7700-000015','noah.smith15@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Emma','Johnson','+1-202-0000016','emma.johnson16@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Oliver','Brown','+44-7700-000017','oliver.brown17@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Ava','Davis','+1-202-0000018','ava.davis18@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Liam','Wilson','+1-202-0000019','liam.wilson19@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Mia','Taylor','+1-202-0000020','mia.taylor20@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Ethan','Anderson','+1-202-0000021','ethan.anderson21@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Isabella','Thomas','+1-202-0000022','isabella.thomas22@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('James','Jackson','+1-202-0000023','james.jackson23@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Charlotte','White','+1-202-0000024','charlotte.white24@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Benjamin','Harris','+1-202-0000025','benjamin.harris25@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Amelia','Martin','+1-202-0000026','amelia.martin26@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Lucas','Thompson','+1-202-0000027','lucas.thompson27@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Harper','Garcia','+1-202-0000028','harper.garcia28@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Mason','Martinez','+1-202-0000029','mason.martinez29@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Evelyn','Robinson','+1-202-0000030','evelyn.robinson30@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Logan','Clark','+1-202-0000031','logan.clark31@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Abigail','Rodriguez','+1-202-0000032','abigail.rodriguez32@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Jacob','Lewis','+1-202-0000033','jacob.lewis33@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Emily','Lee','+1-202-0000034','emily.lee34@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Michael','Walker','+1-202-0000035','michael.walker35@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Ella','Hall','+1-202-0000036','ella.hall36@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Alexander','Allen','+1-202-0000037','alexander.allen37@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Avery','Young','+1-202-0000038','avery.young38@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Daniel','Hernandez','+1-202-0000039','daniel.hernandez39@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Scarlett','King','+1-202-0000040','scarlett.king40@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Henry','Wright','+1-202-0000041','henry.wright41@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Grace','Lopez','+1-202-0000042','grace.lopez42@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Owen','Hill','+1-202-0000043','owen.hill43@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Chloe','Scott','+1-202-0000044','chloe.scott44@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Wyatt','Green','+1-202-0000045','wyatt.green45@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Zoey','Adams','+1-202-0000046','zoey.adams46@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Sebastian','Baker','+1-202-0000047','sebastian.baker47@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Lily','Nelson','+1-202-0000048','lily.nelson48@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Jack','Carter','+1-202-0000049','jack.carter49@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Hannah','Mitchell','+1-202-0000050','hannah.mitchell50@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Levi','Perez','+1-202-0000051','levi.perez51@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Nora','Roberts','+1-202-0000052','nora.roberts52@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Samuel','Turner','+1-202-0000053','samuel.turner53@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Riley','Phillips','+1-202-0000054','riley.phillips54@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Isaac','Campbell','+1-202-0000055','isaac.campbell55@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Violet','Parker','+1-202-0000056','violet.parker56@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Gabriel','Evans','+1-202-0000057','gabriel.evans57@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Stella','Edwards','+1-202-0000058','stella.edwards58@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Carter','Collins','+1-202-0000059','carter.collins59@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Penelope','Stewart','+1-202-0000060','penelope.stewart60@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Wyatt','Morris','+1-202-0000061','wyatt.morris61@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Aurora','Rogers','+1-202-0000062','aurora.rogers62@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Owen','Reed','+1-202-0000063','owen.reed63@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Lucy','Cook','+1-202-0000064','lucy.cook64@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Eli','Morgan','+1-202-0000065','eli.morgan65@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Hazel','Bell','+1-202-0000066','hazel.bell66@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Caleb','Murphy','+1-202-0000067','caleb.murphy67@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Paisley','Bailey','+1-202-0000068','paisley.bailey68@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Nathan','Rivera','+1-202-0000069','nathan.rivera69@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Luna','Cooper','+1-202-0000070','luna.cooper70@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Christian','Richardson','+1-202-0000071','christian.richardson71@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Madison','Cox','+1-202-0000072','madison.cox72@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Hunter','Howard','+1-202-0000073','hunter.howard73@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Brooklyn','Ward','+1-202-0000074','brooklyn.ward74@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Aaron','Torres','+1-202-0000075','aaron.torres75@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Addison','Peterson','+1-202-0000076','addison.peterson76@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Evan','Gray','+1-202-0000077','evan.gray77@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Paisley','Ramirez','+1-202-0000078','paisley.ramirez78@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Isaiah','James','+1-202-0000079','isaiah.james79@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Savannah','Watson','+1-202-0000080','savannah.watson80@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Connor','Brooks','+1-202-0000081','connor.brooks81@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Bella','Kelly','+1-202-0000082','bella.kelly82@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Wyatt','Sanders','+1-202-0000083','wyatt.sanders83@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Claire','Price','+1-202-0000084','claire.price84@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Julian','Bennett','+1-202-0000085','julian.bennett85@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Lucy','Wood','+1-202-0000086','lucy.wood86@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Miles','Barnes','+1-202-0000087','miles.barnes87@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Eleanor','Ross','+1-202-0000088','eleanor.ross88@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Asher','Henderson','+1-202-0000089','asher.henderson89@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Violet','Coleman','+1-202-0000090','violet.coleman90@example.com','ADR00030');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Jordan','Jenkins','+1-202-0000091','jordan.jenkins91@example.com','ADR00021');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Maya','Perry','+1-202-0000092','maya.perry92@example.com','ADR00022');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Eli','Powell','+1-202-0000093','eli.powell93@example.com','ADR00023');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Sadie','Long','+1-202-0000094','sadie.long94@example.com','ADR00024');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Thomas','Patterson','+1-202-0000095','thomas.patterson95@example.com','ADR00025');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Ruby','Hughes','+1-202-0000096','ruby.hughes96@example.com','ADR00026');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Colton','Flores','+1-202-0000097','colton.flores97@example.com','ADR00027');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Lydia','Washington','+1-202-0000098','lydia.washington98@example.com','ADR00028');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Parker','Butler','+1-202-0000099','parker.butler99@example.com','ADR00029');
INSERT INTO customer (firstName, lastName, phoneNumber, email, address_ID) VALUES ('Molly','Simmons','+1-202-0000100','molly.simmons100@example.com','ADR00030');
GO

-- room categories
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Standard','HTL00001',89.00,2,20);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Deluxe','HTL00002',120.00,3,28);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Classic','HTL00003',150.00,2,25);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Superior','HTL00004',170.00,2,30);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('City View','HTL00005',110.00,2,22);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Executive','HTL00006',200.00,3,35);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Canal Suite','HTL00007',180.00,3,32);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Comfort','HTL00008',95.00,2,21);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Lake View','HTL00009',210.00,2,34);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Harbor','HTL00010',130.00,2,24);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Royal','HTL00011',160.00,2,29);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Nordic','HTL00012',140.00,2,26);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Harbor View','HTL00013',155.00,2,27);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Fjord Suite','HTL00014',190.00,3,33);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Central','HTL00015',125.00,2,23);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Old Town','HTL00016',100.00,2,20);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Castle View','HTL00017',170.00,2,30);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Acropolis','HTL00018',145.00,2,25);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Gate Room','HTL00019',115.00,2,22);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Danube Suite','HTL00020',175.00,3,31);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Family','HTL00001',130.00,4,35);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Junior Suite','HTL00002',160.00,3,32);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Romantic Suite','HTL00003',220.00,2,38);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Business','HTL00004',185.00,2,30);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Superior View','HTL00005',140.00,3,27);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Presidential','HTL00006',320.00,4,60);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Canal Deluxe','HTL00007',200.00,3,34);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Economy','HTL00008',80.00,2,18);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Executive Lake','HTL00009',240.00,3,36);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Family Harbor','HTL00010',150.00,4,33);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Executive Royal','HTL00011',190.00,3,31);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Scandinavian Suite','HTL00012',170.00,3,29);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Harbor Junior','HTL00013',165.00,2,28);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Fjord Family','HTL00014',210.00,4,40);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Business Compact','HTL00015',135.00,2,22);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Historic Double','HTL00016',115.00,2,21);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Castle Suite Plus','HTL00017',195.00,3,33);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Acropolis Family','HTL00018',160.00,4,36);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Gate Suite','HTL00019',130.00,3,29);
INSERT INTO roomCategory (categoryTitle, hotel_ID, price, maxGuests, size) VALUES ('Danube Family','HTL00020',200.00,4,38);
GO

-- rooms
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00001','101','RCT00001','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00001','102','RCT00001','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00002','201','RCT00002','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00002','202','RCT00002','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00003','301','RCT00003','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00003','302','RCT00003','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00004','101','RCT00004','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00004','102','RCT00004','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00005','201','RCT00005','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00005','202','RCT00005','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00006','301','RCT00006','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00006','302','RCT00006','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00007','101','RCT00007','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00007','102','RCT00007','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00008','201','RCT00008','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00008','202','RCT00008','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00009','301','RCT00009','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00009','302','RCT00009','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00010','101','RCT00010','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00010','102','RCT00010','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00011','201','RCT00011','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00011','202','RCT00011','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00012','301','RCT00012','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00012','302','RCT00012','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00013','101','RCT00013','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00013','102','RCT00013','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00014','201','RCT00014','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00014','202','RCT00014','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00015','301','RCT00015','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00015','302','RCT00015','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00016','101','RCT00016','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00016','102','RCT00016','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00017','201','RCT00017','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00017','202','RCT00017','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00018','301','RCT00018','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00018','302','RCT00018','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00019','101','RCT00019','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00019','102','RCT00019','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00020','201','RCT00020','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00020','202','RCT00020','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00001','103','RCT00021','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00001','104','RCT00021','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00002','203','RCT00022','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00002','204','RCT00022','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00003','303','RCT00023','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00003','304','RCT00023','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00004','103','RCT00024','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00004','104','RCT00024','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00005','203','RCT00025','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00005','204','RCT00025','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00006','303','RCT00026','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00006','304','RCT00026','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00007','103','RCT00027','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00007','104','RCT00027','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00008','203','RCT00028','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00008','204','RCT00028','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00009','303','RCT00029','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00009','304','RCT00029','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00010','103','RCT00030','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00010','104','RCT00030','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00011','203','RCT00031','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00011','204','RCT00031','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00012','303','RCT00032','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00012','304','RCT00032','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00013','103','RCT00033','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00013','104','RCT00033','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00014','203','RCT00034','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00014','204','RCT00034','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00015','303','RCT00035','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00015','304','RCT00035','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00016','103','RCT00036','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00016','104','RCT00036','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00017','203','RCT00037','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00017','204','RCT00037','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00018','303','RCT00038','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00018','304','RCT00038','3');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00019','103','RCT00039','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00019','104','RCT00039','1');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00020','203','RCT00040','2');
INSERT INTO room (hotel_ID, roomNumber, roomCategory_ID, floor) VALUES ('HTL00020','204','RCT00040','2');
GO

-- reservations
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00001','2025-06-01 14:00:00','2025-06-05 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00002','2025-06-03 15:00:00','2025-06-04 10:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00003','2025-07-10 16:00:00','2025-07-15 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00004','2025-08-01 14:00:00','2025-08-03 11:00:00',1,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00005','2025-09-12 13:00:00','2025-09-15 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00006','2025-10-05 14:00:00','2025-10-07 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00007','2025-11-20 15:00:00','2025-11-22 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00008','2025-12-24 16:00:00','2025-12-27 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00009','2025-05-01 14:00:00','2025-05-02 11:00:00',1,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00010','2025-04-10 14:00:00','2025-04-12 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00011','2025-06-11 14:00:00','2025-06-13 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00012','2025-07-01 14:00:00','2025-07-04 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00013','2025-07-20 14:00:00','2025-07-22 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00014','2025-08-15 14:00:00','2025-08-18 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00015','2025-09-01 14:00:00','2025-09-02 11:00:00',1,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00016','2025-10-10 14:00:00','2025-10-12 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00017','2025-11-01 14:00:00','2025-11-05 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00018','2025-12-01 14:00:00','2025-12-03 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00019','2025-05-20 14:00:00','2025-05-22 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00020','2025-04-20 14:00:00','2025-04-25 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00021','2025-06-21 14:00:00','2025-06-23 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00022','2025-07-11 14:00:00','2025-07-13 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00023','2025-08-05 14:00:00','2025-08-08 11:00:00',2,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00024','2025-09-10 14:00:00','2025-09-12 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00025','2025-10-15 14:00:00','2025-10-18 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00026','2025-11-10 14:00:00','2025-11-12 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00027','2025-12-05 14:00:00','2025-12-07 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00028','2025-05-25 14:00:00','2025-05-27 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00029','2025-04-01 14:00:00','2025-04-03 11:00:00',2,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00030','2025-06-30 14:00:00','2025-07-02 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00031','2025-07-30 14:00:00','2025-08-02 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00032','2025-08-20 14:00:00','2025-08-22 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00033','2025-09-05 14:00:00','2025-09-07 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00034','2025-10-01 14:00:00','2025-10-04 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00035','2025-11-15 14:00:00','2025-11-18 11:00:00',3,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00036','2025-12-20 14:00:00','2025-12-23 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00037','2025-05-10 14:00:00','2025-05-12 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00038','2025-04-15 14:00:00','2025-04-17 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00039','2025-06-05 14:00:00','2025-06-07 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00040','2025-07-12 14:00:00','2025-07-15 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00041','2025-08-08 14:00:00','2025-08-10 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00042','2025-09-18 14:00:00','2025-09-20 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00043','2025-10-22 14:00:00','2025-10-25 11:00:00',2,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00044','2025-11-02 14:00:00','2025-11-04 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00045','2025-12-12 14:00:00','2025-12-14 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00046','2025-05-14 14:00:00','2025-05-16 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00047','2025-06-25 14:00:00','2025-06-27 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00048','2025-07-05 14:00:00','2025-07-07 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00049','2025-08-28 14:00:00','2025-08-30 11:00:00',2,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00050','2025-09-09 14:00:00','2025-09-11 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00001','2025-01-10 14:00:00','2025-01-13 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00005','2024-11-15 14:00:00','2024-11-17 11:00:00',3,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00012','2024-12-20 14:00:00','2024-12-23 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00018','2025-02-05 14:00:00','2025-02-07 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00023','2024-10-01 14:00:00','2024-10-03 11:00:00',2,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00031','2025-03-01 14:00:00','2025-03-04 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00040','2024-09-14 14:00:00','2024-09-16 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00047','2025-01-22 14:00:00','2025-01-25 11:00:00',3,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00055','2024-08-05 14:00:00','2024-08-08 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00063','2025-02-14 14:00:00','2025-02-16 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00071','2024-12-01 14:00:00','2024-12-03 11:00:00',1,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00079','2025-03-10 14:00:00','2025-03-13 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00086','2024-07-20 14:00:00','2024-07-22 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests, status) VALUES ('CUS00093','2025-01-05 14:00:00','2025-01-07 11:00:00',1,'C');
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00100','2025-03-25 14:00:00','2025-03-28 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00003','2026-04-04 14:00:00','2026-04-08 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00010','2026-04-05 14:00:00','2026-04-07 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00017','2026-04-03 14:00:00','2026-04-09 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00025','2026-04-01 14:00:00','2026-04-10 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00033','2026-04-06 00:00:00','2026-04-12 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00042','2026-04-02 14:00:00','2026-04-07 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00050','2026-04-04 14:00:00','2026-04-11 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00058','2026-04-05 14:00:00','2026-04-08 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00066','2026-04-03 14:00:00','2026-04-13 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00074','2026-04-01 14:00:00','2026-04-07 11:00:00',3);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00082','2026-04-05 14:00:00','2026-04-09 11:00:00',2);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00090','2026-04-02 14:00:00','2026-04-08 11:00:00',1);
INSERT INTO reservation (customer_ID, checkin, checkout, guests) VALUES ('CUS00097','2026-04-04 14:00:00','2026-04-14 11:00:00',2);
GO

-- invoices
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00001',426.00,'2025-06-05','ADR00021');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00003',810.00,'2025-07-15','ADR00023');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00005',363.00,'2025-09-15','ADR00025');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00007',404.00,'2025-11-22','ADR00027');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00010',260.00,'2025-04-12','ADR00030');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00012',420.00,'2025-07-04','ADR00022');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00014',590.00,'2025-08-18','ADR00024');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00016',268.00,'2025-10-12','ADR00026');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00018',290.00,'2025-12-03','ADR00028');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00020',875.00,'2025-04-25','ADR00030');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00022',250.00,'2025-07-13','ADR00022');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00024',340.00,'2025-09-12','ADR00024');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00026',400.00,'2025-11-12','ADR00026');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00028',190.00,'2025-05-27','ADR00028');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00030',284.00,'2025-07-02','ADR00030');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00032',280.00,'2025-08-22','ADR00022');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00034',570.00,'2025-10-04','ADR00024');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00036',340.00,'2025-12-23','ADR00026');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00038',290.00,'2025-04-17','ADR00028');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00040',525.00,'2025-07-15','ADR00030');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00042',240.00,'2025-09-20','ADR00022');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00044',340.00,'2025-11-04','ADR00024');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00046',400.00,'2025-05-16','ADR00026');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00048',190.00,'2025-07-07','ADR00028');
INSERT INTO invoice (reservation_ID, totalPrice, invoiceDate, address_ID) VALUES ('RES00050',278.00,'2025-09-11','ADR00030');
GO

-- room reservations
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00001','101','RES00001');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00002','201','RES00002');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00003','301','RES00003');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00004','101','RES00004');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00005','201','RES00005');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00006','301','RES00006');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00007','101','RES00007');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00008','201','RES00008');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00009','301','RES00009');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00010','101','RES00010');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00011','201','RES00011');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00012','301','RES00012');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00013','101','RES00013');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00014','201','RES00014');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00015','301','RES00015');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00016','101','RES00016');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00017','201','RES00017');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00018','301','RES00018');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00019','101','RES00019');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00020','201','RES00020');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00001','102','RES00021');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00002','202','RES00022');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00003','302','RES00023');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00004','102','RES00024');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00005','202','RES00025');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00006','302','RES00026');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00007','102','RES00027');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00008','202','RES00028');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00009','302','RES00029');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00010','102','RES00030');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00011','202','RES00031');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00012','302','RES00032');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00013','102','RES00033');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00014','202','RES00034');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00015','302','RES00035');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00016','102','RES00036');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00017','202','RES00037');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00018','302','RES00038');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00019','102','RES00039');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00020','202','RES00040');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00001','101','RES00041');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00002','201','RES00042');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00003','301','RES00043');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00004','101','RES00044');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00005','201','RES00045');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00006','301','RES00046');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00007','101','RES00047');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00008','201','RES00048');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00009','301','RES00049');
INSERT INTO room_reservation (hotel_ID, roomNumber, reservation_ID) VALUES ('HTL00010','101','RES00050');
GO

-- equipment
INSERT INTO equipment (equipmentTitle) VALUES ('TV');
INSERT INTO equipment (equipmentTitle) VALUES ('Minibar');
INSERT INTO equipment (equipmentTitle) VALUES ('Safe');
INSERT INTO equipment (equipmentTitle) VALUES ('Coffee Machine');
INSERT INTO equipment (equipmentTitle) VALUES ('Extra Bed');
GO

-- room category equipment
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00001','EQP00001',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00001','EQP00003',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00002','EQP00001',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00002','EQP00002',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00006','EQP00004',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00006','EQP00005',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00009','EQP00001',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00014','EQP00005',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00020','EQP00002',1);
INSERT INTO roomCategory_equipment (roomCategory_ID, equipment_ID, amount) VALUES ('RCT00011','EQP00003',1);
GO

-- additional options
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00001',12.50);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('AirportPickup','HTL00001',45.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00002',14.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Parking','HTL00002',10.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00003',15.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('SpaAccess','HTL00003',30.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00004',13.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('LateCheckout','HTL00004',20.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00005',11.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('CityTour','HTL00005',25.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00006',18.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('AirportPickup','HTL00006',50.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00007',16.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('CanalRide','HTL00007',22.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00008',10.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Parking','HTL00008',8.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00009',20.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('LakeCruise','HTL00009',60.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('Breakfast','HTL00010',12.00);
INSERT INTO additionalOption (additionalOptionTitle, hotel_ID, price) VALUES ('HarborShuttle','HTL00010',18.00);
GO

-- reservation additional options
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00001','RES00001',2);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('AirportPickup','HTL00001','RES00001',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00003','RES00003',2);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('SpaAccess','HTL00003','RES00003',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00005','RES00005',3);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('CanalRide','HTL00007','RES00007',2);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00012','RES00012',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('LateCheckout','HTL00004','RES00014',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Parking','HTL00002','RES00022',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00010','RES00030',2);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00006','RES00016',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('AirportPickup','HTL00006','RES00016',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00009','RES00036',2);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('Breakfast','HTL00020','RES00040',1);
INSERT INTO reservation_additionalOption (additionalOptionTitle, hotel_ID, reservation_ID, amount) VALUES ('HarborShuttle','HTL00010','RES00050',1);
GO


-- #############################################
-- #                  Indexes                  #
-- #############################################
CREATE INDEX idx_address_country        ON [address](country);
CREATE INDEX idx_address_city           ON [address](city);
CREATE INDEX idx_address_city_district  ON [address](city, district);
CREATE INDEX idx_reservation_checkin    ON reservation(checkin);
CREATE INDEX idx_reservation_checkout   ON reservation(checkout);
GO


-- #############################################
-- #                 SQL Views                 #
-- #############################################

-- ── Customer views (per-user, demo_customer = CUS00001) ───────────────────────

CREATE VIEW view_customer_demo_customer AS
SELECT customer_ID, firstName, lastName, phoneNumber, email, address_ID
FROM customer
WHERE customer_ID = 'CUS00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_reservation_demo_customer AS
SELECT reservation_ID, customer_ID, checkin, checkout, guests, [status]
FROM reservation
WHERE customer_ID = 'CUS00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_address_demo_customer AS
SELECT address_ID, country, city, district, streetAddress
FROM [address]
WHERE address_ID IN (
    SELECT address_ID FROM customer WHERE customer_ID = 'CUS00001'
);
GO

CREATE VIEW view_reservation_additionalOption_demo_customer AS
SELECT additionalOptionTitle, hotel_ID, reservation_ID, amount
FROM reservation_additionalOption
WHERE reservation_ID IN (
    SELECT reservation_ID FROM reservation WHERE customer_ID = 'CUS00001'
)
WITH CHECK OPTION;
GO

CREATE VIEW view_invoice_demo_customer AS
SELECT iv.reservation_ID, iv.totalPrice, iv.invoiceDate,
       ad.country, ad.city, ad.district, ad.streetAddress
FROM invoice iv
INNER JOIN [address] ad ON iv.address_ID = ad.address_ID
WHERE iv.reservation_ID IN (
    SELECT reservation_ID FROM reservation WHERE customer_ID = 'CUS00001'
);
GO

CREATE VIEW view_room_reservation_demo_customer AS
SELECT hotel_ID, roomNumber, reservation_ID
FROM room_reservation
WHERE reservation_ID IN (
    SELECT reservation_ID FROM reservation WHERE customer_ID = 'CUS00001'
)
WITH CHECK OPTION;
GO

-- ── Customer views (role-level) ────────────────────────────────────────────────

CREATE VIEW view_roomCategory_customer AS
SELECT roomCategory_ID, categoryTitle, hotel_ID, price, maxGuests, [size]
FROM roomCategory;
GO

CREATE VIEW view_roomCategory_equipment_customer AS
SELECT roomCategory_ID, equipment_ID, amount
FROM roomCategory_equipment;
GO

CREATE VIEW view_room_customer AS
SELECT hotel_ID, roomNumber, roomCategory_ID, [floor]
FROM room;
GO

CREATE VIEW view_equipment_customer AS
SELECT equipment_ID, equipmentTitle
FROM equipment;
GO

CREATE VIEW view_additionalOption_customer AS
SELECT additionalOptionTitle, hotel_ID, price
FROM additionalOption;
GO

CREATE VIEW view_hotel_customer AS
SELECT ho.hotel_ID, ho.hotelName, ho.phoneNumber, ho.email,
       ad.country, ad.city, ad.district, ad.streetAddress
FROM hotel ho
INNER JOIN [address] ad ON ho.address_ID = ad.address_ID;
GO

-- ── Hotel staff views (per-user, demo_hotel_staff = HTL00001) ─────────────────

CREATE VIEW view_roomCategory_demo_hotel_staff AS
SELECT roomCategory_ID, categoryTitle, hotel_ID, price, maxGuests, [size]
FROM roomCategory
WHERE hotel_ID = 'HTL00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_roomCategory_equipment_demo_hotel_staff AS
SELECT roomCategory_ID, equipment_ID, amount
FROM roomCategory_equipment
WHERE roomCategory_ID IN (
    SELECT roomCategory_ID FROM roomCategory WHERE hotel_ID = 'HTL00001'
)
WITH CHECK OPTION;
GO

CREATE VIEW view_customer_demo_hotel_staff AS
SELECT customer_ID, firstName, lastName, phoneNumber, email, address_ID
FROM customer
WHERE customer_ID IN (
    SELECT customer_ID FROM reservation
    WHERE reservation_ID IN (
        SELECT reservation_ID FROM room_reservation WHERE hotel_ID = 'HTL00001'
    )
);
GO

CREATE VIEW view_reservation_demo_hotel_staff AS
SELECT reservation_ID, customer_ID, checkin, checkout, guests, [status]
FROM reservation
WHERE reservation_ID IN (
    SELECT reservation_ID FROM room_reservation WHERE hotel_ID = 'HTL00001'
)
WITH CHECK OPTION;
GO

CREATE VIEW view_address_demo_hotel_staff AS
SELECT address_ID, country, city, district, streetAddress
FROM [address];
GO

CREATE VIEW view_reservation_additionalOption_demo_hotel_staff AS
SELECT additionalOptionTitle, hotel_ID, reservation_ID, amount
FROM reservation_additionalOption
WHERE hotel_ID = 'HTL00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_invoice_demo_hotel_staff AS
SELECT reservation_ID, totalPrice, invoiceDate, address_ID
FROM invoice
WHERE reservation_ID IN (
    SELECT reservation_ID FROM room_reservation WHERE hotel_ID = 'HTL00001'
)
WITH CHECK OPTION;
GO

CREATE VIEW view_room_reservation_demo_hotel_staff AS
SELECT hotel_ID, roomNumber, reservation_ID
FROM room_reservation
WHERE hotel_ID = 'HTL00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_room_demo_hotel_staff AS
SELECT hotel_ID, roomNumber, roomCategory_ID, [floor]
FROM room
WHERE hotel_ID = 'HTL00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_additionalOption_demo_hotel_staff AS
SELECT additionalOptionTitle, hotel_ID, price
FROM additionalOption
WHERE hotel_ID = 'HTL00001'
WITH CHECK OPTION;
GO

CREATE VIEW view_hotel_demo_hotel_staff AS
SELECT hotel_ID, hotelName, phoneNumber, email, address_ID
FROM hotel
WHERE hotel_ID = 'HTL00001';
GO

-- ── Hotel staff views (role-level) ────────────────────────────────────────────

CREATE VIEW view_equipment_hotel_staff AS
SELECT equipment_ID, equipmentTitle
FROM equipment;
GO

-- General hotel-staff view: all active (Reserved / Paid) reservations
CREATE VIEW view_general_current_reservations AS
SELECT re.reservation_ID, re.customer_ID, re.checkin, re.checkout,
       re.guests, re.[status], rr.hotel_ID, rr.roomNumber
FROM reservation re
INNER JOIN room_reservation rr ON re.reservation_ID = rr.reservation_ID
WHERE re.[status] IN ('R', 'P');
GO

-- ── System admin views (role-level) ───────────────────────────────────────────

CREATE VIEW view_customer_system_admin AS
SELECT customer_ID, firstName, lastName, phoneNumber, email, address_ID
FROM customer;
GO

CREATE VIEW view_reservation_system_admin AS
SELECT reservation_ID, customer_ID, checkin, checkout, guests, [status]
FROM reservation;
GO

CREATE VIEW view_address_system_admin AS
SELECT address_ID, country, city, district, streetAddress
FROM [address];
GO

CREATE VIEW view_reservation_additionalOption_system_admin AS
SELECT additionalOptionTitle, hotel_ID, reservation_ID, amount
FROM reservation_additionalOption;
GO

CREATE VIEW view_invoice_system_admin AS
SELECT reservation_ID, totalPrice, invoiceDate, address_ID
FROM invoice;
GO

CREATE VIEW view_room_reservation_system_admin AS
SELECT hotel_ID, roomNumber, reservation_ID
FROM room_reservation;
GO

CREATE VIEW view_room_system_admin AS
SELECT hotel_ID, roomNumber, roomCategory_ID, [floor]
FROM room;
GO

CREATE VIEW view_equipment_system_admin AS
SELECT equipment_ID, equipmentTitle
FROM equipment;
GO

CREATE VIEW view_additionalOption_system_admin AS
SELECT additionalOptionTitle, hotel_ID, price
FROM additionalOption;
GO

CREATE VIEW view_hotel_system_admin AS
SELECT ho.hotel_ID, ho.hotelName, ho.phoneNumber, ho.email,
       ad.country, ad.city, ad.district, ad.streetAddress
FROM hotel ho
INNER JOIN [address] ad ON ho.address_ID = ad.address_ID;
GO

CREATE VIEW view_roomCategory_system_admin AS
SELECT roomCategory_ID, categoryTitle, hotel_ID, price, maxGuests, size
FROM roomCategory;
GO

CREATE VIEW view_roomCategory_equipment_system_admin AS
SELECT roomCategory_ID, equipment_ID, amount
FROM roomCategory_equipment;
GO

-- General customer views (role-level, read-only booking context)
CREATE VIEW view_general_reservation AS
SELECT reservation_ID, customer_ID, checkin, checkout, guests, [status]
FROM reservation;
GO

CREATE VIEW view_general_room_reservation AS
SELECT hotel_ID, roomNumber, reservation_ID
FROM room_reservation;
GO


-- ##################################################
-- #   User-defined Functions & Stored Procedures   #
-- ##################################################

-- Return the full name of a customer
CREATE FUNCTION FN_FULL_NAME (
    @firstName VARCHAR(50),
    @lastName  VARCHAR(50)
)
RETURNS VARCHAR(101)
AS
BEGIN
    RETURN CONCAT(@firstName, ' ', @lastName);
END;
GO

-- Return a human-readable label for each reservation status code
CREATE FUNCTION FN_STATUS_DETAILS (
    @status CHAR(1)
)
RETURNS VARCHAR(14)
AS
BEGIN
    RETURN CASE @status
        WHEN 'P' THEN 'Payed'
        WHEN 'C' THEN 'Cancelled'
        WHEN 'R' THEN 'Reserved'
        ELSE 'Invalid Status'
    END;
END;
GO

-- Format a price value as a euro string
CREATE FUNCTION FN_FORMAT_PRICE (
    @price DECIMAL(10,2)
)
RETURNS VARCHAR(11)
AS
BEGIN
    RETURN CONCAT(COALESCE(@price, 0.00), '€');
END;
GO

-- Calculate the total price of a reservation (room nights + add-ons)
CREATE FUNCTION FN_GET_RESERVATION_PRICE (
    @reservation_ID VARCHAR(8)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN (
        SELECT TOP 1 COALESCE(SUM(ra.amount * ao.price), 0)
        FROM reservation_additionalOption ra
        INNER JOIN additionalOption ao
            ON  ra.additionalOptionTitle = ao.additionalOptionTitle
            AND ra.hotel_ID              = ao.hotel_ID
        WHERE ra.reservation_ID = @reservation_ID
    ) + (
        SELECT TOP 1 COALESCE(DATEDIFF(day, re.checkin, re.checkout) * rc.price, 0)
        FROM reservation re
        INNER JOIN room_reservation rr ON re.reservation_ID = rr.reservation_ID
        INNER JOIN room             ro ON ro.roomNumber  = rr.roomNumber
                                      AND ro.hotel_ID    = rr.hotel_ID
        INNER JOIN roomCategory     rc ON ro.roomCategory_ID = rc.roomCategory_ID
        WHERE re.reservation_ID = @reservation_ID
    );
END;
GO

-- Return all rooms that are free for the requested date range
CREATE FUNCTION FN_GET_AVAILABLE_ROOMS (
    @checkin  DATE,
    @checkout DATE
)
RETURNS TABLE
AS
RETURN
    SELECT ro.hotel_ID, ro.roomNumber, ro.roomCategory_ID
    FROM room ro
    WHERE NOT EXISTS (
        SELECT 1
        FROM room_reservation rr
        LEFT OUTER JOIN reservation re ON rr.reservation_ID = re.reservation_ID
        WHERE ro.roomNumber = rr.roomNumber
          AND ro.hotel_ID   = rr.hotel_ID
          AND re.[status]  IN ('P', 'R')
          AND re.checkin    < @checkout
          AND re.checkout   > @checkin
    );
GO

-- Create a new hotel together with its address in one call
CREATE PROCEDURE SP_CREATE_HOTEL
    @hotel_name          VARCHAR(100),
    @hotel_phoneNumber   VARCHAR(20),
    @hotel_email         VARCHAR(254),
    @hotel_country       VARCHAR(60),
    @hotel_city          VARCHAR(200),
    @hotel_district      VARCHAR(50),
    @hotel_streetAddress VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO address (country, city, district, streetAddress)
        VALUES (@hotel_country, @hotel_city, @hotel_district, @hotel_streetAddress);

        DECLARE @address_ID VARCHAR(8);
        SELECT TOP 1 @address_ID = address_ID
        FROM address WHERE internal_ID = SCOPE_IDENTITY();

        INSERT INTO hotel (hotelName, phoneNumber, email, address_ID)
        VALUES (@hotel_name, @hotel_phoneNumber, @hotel_email, @address_ID);

        PRINT 'Hotel was successfully created.';
    END TRY
    BEGIN CATCH
        PRINT 'Error: Failed to create hotel. ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- Create a reservation and assign available rooms automatically
CREATE PROCEDURE SP_CREATE_RESERVATION
    @res_customer_ID    VARCHAR(8),
    @res_checkin        DATE,
    @res_checkout       DATE,
    @res_guests         SMALLINT,
    @res_hotel_ID       VARCHAR(8),
    @res_room_count     SMALLINT,
    @res_roomCategory_ID VARCHAR(8)
AS
BEGIN
    SET NOCOUNT ON;

    IF @res_checkin > @res_checkout
    BEGIN
        PRINT 'Error: Checkin cannot be after Checkout.';
        RETURN;
    END;

    IF (
        SELECT @res_room_count * maxGuests
        FROM roomCategory WHERE roomCategory_ID = @res_roomCategory_ID
    ) < @res_guests
    BEGIN
        PRINT 'Error: Too many guests.';
        RETURN;
    END;

    IF (
        SELECT TOP 1 hotel_ID
        FROM roomCategory WHERE roomCategory_ID = @res_roomCategory_ID
    ) != @res_hotel_ID
    BEGIN
        PRINT 'Error: Room category does not belong to the specified hotel';
        RETURN;
    END;

    DECLARE @customer_exists INT = 0;
    SELECT @customer_exists = COUNT(*) FROM customer WHERE customer_ID = @res_customer_ID;
    IF @customer_exists = 0
    BEGIN
        PRINT 'Error: The customer does not exist.';
        RETURN;
    END;

    IF (
        SELECT COUNT(*)
        FROM dbo.FN_GET_AVAILABLE_ROOMS(@res_checkin, @res_checkout)
        WHERE hotel_ID       = @res_hotel_ID
          AND roomCategory_ID = @res_roomCategory_ID
    ) < @res_room_count
    BEGIN
        PRINT 'Error: There are not enough rooms available in this category.';
        RETURN;
    END;

    BEGIN TRY
        INSERT INTO reservation (customer_ID, checkin, checkout, guests)
        VALUES (
            @res_customer_ID,
            DATEADD(hour, 14, CAST(@res_checkin  AS DATETIME)),
            DATEADD(hour, 11, CAST(@res_checkout AS DATETIME)),
            @res_guests
        );

        DECLARE @reservation_ID VARCHAR(8);
        SELECT TOP 1 @reservation_ID = reservation_ID
        FROM reservation WHERE internal_ID = SCOPE_IDENTITY();

        DECLARE @i INT = 0;
        DECLARE @currentRoomNumber VARCHAR(7);
        WHILE @i < @res_room_count
        BEGIN
            SELECT TOP 1 @currentRoomNumber = ro.roomNumber
            FROM dbo.FN_GET_AVAILABLE_ROOMS(@res_checkin, @res_checkout) ro
            WHERE ro.hotel_ID        = @res_hotel_ID
              AND ro.roomCategory_ID = @res_roomCategory_ID;

            INSERT INTO room_reservation (reservation_ID, hotel_ID, roomNumber)
            VALUES (@reservation_ID, @res_hotel_ID, @currentRoomNumber);

            SET @i = @i + 1;
        END;

        PRINT 'Reservation created successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error: Failed to create reservation. ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-- ##################################################
-- #                    Triggers                    #
-- ##################################################

-- Recalculate invoice total and mark reservation as Paid after an invoice is inserted
CREATE TRIGGER TRG_INVOICE_AFTER_INSERT
ON invoice
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @reservation_ID VARCHAR(8);
    SELECT TOP 1 @reservation_ID = reservation_ID FROM inserted;

    UPDATE re
    SET re.status = 'P'
    FROM reservation re
    WHERE reservation_ID = @reservation_ID;

    UPDATE iv
    SET iv.totalPrice  = dbo.FN_GET_RESERVATION_PRICE(@reservation_ID),
        iv.invoiceDate = GETDATE()
    FROM invoice iv
    WHERE iv.reservation_ID = @reservation_ID;
END;
GO

-- Reset reservation status to Reserved when its invoice is deleted
CREATE TRIGGER TRG_INVOICE_AFTER_DELETE
ON invoice
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @reservation_ID VARCHAR(8);
    SELECT TOP 1 @reservation_ID = reservation_ID FROM deleted;

    UPDATE reservation
    SET status = 'R'
    WHERE reservation_ID = @reservation_ID
      AND status = 'P';
END;
GO

-- Remove invoice when a reservation is cancelled (saves storage)
CREATE TRIGGER TRG_AFTER_RESERVATION_CANCELLED
ON reservation
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @reservation_ID VARCHAR(8);
    SELECT TOP 1 @reservation_ID = reservation_ID FROM inserted;

    IF (
        SELECT status FROM reservation WHERE reservation_ID = @reservation_ID
    ) = 'C'
    BEGIN
        DELETE FROM invoice WHERE reservation_ID = @reservation_ID;
    END;
END;
GO

-- Prevent a room from being assigned a room category belonging to a different hotel
CREATE TRIGGER TRG_VALIDATE_ROOM_ROOMCAT
ON room
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(roomCategory_ID) OR UPDATE(hotel_ID)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM roomCategory rc
            INNER JOIN inserted it ON rc.roomCategory_ID = it.roomCategory_ID
            WHERE rc.hotel_ID != it.hotel_ID
        )
        BEGIN
            RAISERROR('Rooms cannot have room categories from other hotels', 16, 1);
            ROLLBACK TRANSACTION;
        END;
    END;
END;
GO

-- Prevent a room category from being moved to a hotel that already has rooms pointing to it
CREATE TRIGGER TRG_VALIDATE_ROOMCAT_HOTEL_ID
ON roomCategory
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(hotel_ID)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM room ro
            INNER JOIN inserted it ON ro.roomCategory_ID = it.roomCategory_ID
            WHERE ro.hotel_ID != it.hotel_ID
        )
        BEGIN
            RAISERROR('Rooms cannot have room categories from other hotels', 16, 1);
            ROLLBACK TRANSACTION;
        END;
    END;
END;
GO

-- Prevent additional options from a different hotel being linked to a reservation
CREATE TRIGGER TRG_VALIDATE_OPTION_HOTEL_ID
ON reservation_additionalOption
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(hotel_ID)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM room_reservation rr
            INNER JOIN inserted it ON rr.reservation_ID = it.reservation_ID
            WHERE rr.hotel_ID != it.hotel_ID
        )
        BEGIN
            RAISERROR('Additional booking options cannot belong to other hotel', 16, 1);
            ROLLBACK TRANSACTION;
        END;
    END;
END;
GO

-- Prevent rooms from different hotels being mixed within one reservation
CREATE TRIGGER TRG_VALIDATE_ROOM_RESERVATIONS
ON room_reservation
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM room_reservation rr
        INNER JOIN inserted it ON rr.reservation_ID = it.reservation_ID
        WHERE rr.hotel_ID != it.hotel_ID
    )
    BEGIN
        RAISERROR('You can only reserve rooms from the same hotel', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO


-- ##################################################
-- #                 Authorization                  #
-- ##################################################

CREATE ROLE customer;
GO
CREATE ROLE hotel_staff;
GO
CREATE ROLE system_admin;
GO

CREATE USER demo_customer    FOR LOGIN demo_customer;
CREATE USER demo_hotel_staff FOR LOGIN hotel_staff;
CREATE USER demo_system_admin FOR LOGIN system_admin;
GO

-- Add users to their respective roles
ALTER ROLE customer    ADD MEMBER demo_customer;
ALTER ROLE hotel_staff ADD MEMBER demo_hotel_staff;
ALTER ROLE system_admin ADD MEMBER demo_system_admin;
GO

-- Function permissions
GRANT EXECUTE ON dbo.FN_FORMAT_PRICE          TO customer;
GRANT EXECUTE ON dbo.FN_FORMAT_PRICE          TO hotel_staff;
GRANT EXECUTE ON dbo.FN_FORMAT_PRICE          TO system_admin;
GRANT EXECUTE ON dbo.FN_STATUS_DETAILS        TO customer;
GRANT EXECUTE ON dbo.FN_STATUS_DETAILS        TO hotel_staff;
GRANT EXECUTE ON dbo.FN_STATUS_DETAILS        TO system_admin;
GRANT SELECT  ON dbo.FN_GET_AVAILABLE_ROOMS   TO customer;
GRANT SELECT  ON dbo.FN_GET_AVAILABLE_ROOMS   TO system_admin;
GRANT EXECUTE ON dbo.FN_GET_RESERVATION_PRICE TO customer;
GRANT EXECUTE ON dbo.FN_GET_RESERVATION_PRICE TO hotel_staff;
GRANT EXECUTE ON dbo.FN_GET_RESERVATION_PRICE TO system_admin;

-- Stored procedure permissions
GRANT EXECUTE ON dbo.SP_CREATE_HOTEL        TO hotel_staff;
GRANT EXECUTE ON dbo.SP_CREATE_HOTEL        TO system_admin;
GRANT EXECUTE ON dbo.SP_CREATE_RESERVATION  TO customer;
GRANT EXECUTE ON dbo.SP_CREATE_RESERVATION  TO system_admin;

-- demo_customer view permissions
GRANT SELECT, UPDATE, DELETE            ON view_customer_demo_customer                    TO demo_customer;
GRANT SELECT, INSERT, UPDATE            ON view_reservation_demo_customer                 TO demo_customer;
GRANT SELECT, INSERT, UPDATE            ON view_address_demo_customer                     TO demo_customer;
GRANT SELECT, INSERT, UPDATE, DELETE    ON view_reservation_additionalOption_demo_customer TO demo_customer;
GRANT SELECT                            ON view_invoice_demo_customer                     TO demo_customer;
GRANT SELECT, INSERT, DELETE            ON view_room_reservation_demo_customer            TO demo_customer;

-- customer role view permissions
GRANT SELECT ON view_room_customer                  TO customer;
GRANT SELECT ON view_equipment_customer             TO customer;
GRANT SELECT ON view_additionalOption_customer      TO customer;
GRANT SELECT ON view_hotel_customer                 TO customer;
GRANT SELECT ON view_roomCategory_customer          TO customer;
GRANT SELECT ON view_roomCategory_equipment_customer TO customer;
GRANT SELECT ON view_general_reservation            TO customer;
GRANT SELECT ON view_general_room_reservation       TO customer;

-- demo_hotel_staff view permissions
GRANT SELECT                         ON view_customer_demo_hotel_staff                    TO demo_hotel_staff;
GRANT SELECT, UPDATE, DELETE         ON view_reservation_demo_hotel_staff                 TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_address_demo_hotel_staff                     TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_reservation_additionalOption_demo_hotel_staff TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_invoice_demo_hotel_staff                     TO demo_hotel_staff;
GRANT SELECT, INSERT, DELETE         ON view_room_reservation_demo_hotel_staff            TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_room_demo_hotel_staff                        TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_additionalOption_demo_hotel_staff            TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_hotel_demo_hotel_staff                       TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_roomCategory_demo_hotel_staff                TO demo_hotel_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_roomCategory_equipment_demo_hotel_staff      TO demo_hotel_staff;
GRANT SELECT                         ON view_equipment_demo_hotel_staff                   TO demo_hotel_staff;

-- hotel_staff role view permissions
GRANT SELECT ON view_general_current_reservations TO hotel_staff;

-- system_admin view permissions (full access)
GRANT SELECT, INSERT, UPDATE, DELETE ON view_customer_system_admin                  TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_reservation_system_admin               TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_address_system_admin                   TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_reservation_additionalOption_system_admin TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_invoice_system_admin                   TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_room_reservation_system_admin          TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_room_system_admin                      TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_equipment_system_admin                 TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_additionalOption_system_admin          TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_hotel_system_admin                     TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_roomCategory_system_admin              TO system_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON view_roomCategory_equipment_system_admin    TO system_admin;
GO