-- @system_management_system_overview_kpi_0
SELECT COUNT(*) AS number_of_customers
FROM view_customer_[customer];

-- @system_management_system_overview_kpi_1
SELECT COUNT(*) AS number_of_hotels
FROM view_hotel_[hotel];

-- @system_management_system_overview_kpi_2
SELECT COUNT(*) AS active_reservations
FROM view_reservation_[reservation]
WHERE checkout >= GETDATE();

-- @system_management_running_total_reservations_sql
WITH ReservationMonthYear AS (
	SELECT reservation_ID, MONTH(checkin) AS month_num, YEAR(checkin) AS [year], DATENAME(month , checkin) AS [month]
	FROM view_reservation_[reservation]
)
SELECT [year], [month], COUNT(reservation_ID) AS monthly_reservations, 
	SUM(COUNT(reservation_ID)) OVER(ORDER BY [year], month_num ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_reservations
FROM ReservationMonthYear
GROUP BY [year], [month], month_num
ORDER BY [year] DESC, month_num DESC;

-- @system_management_contact_information_sql
SELECT cu.customer_ID AS ID, CONCAT(cu.firstName,' ',cu.lastName) AS [name], cu.phoneNumber AS phoneNumber, cu.email AS email, ad.country, ad.district, ad.streetAddress 
FROM view_customer_[customer] cu 
INNER JOIN view_address_[address] ad ON cu.address_ID = ad.address_ID
UNION (
	SELECT ho.hotel_ID AS ID, ho.hotelName AS [name], ho.phoneNumber AS phoneNumber, ho.email AS email, ad.country, ad.district, ad.streetAddress 
	FROM view_hotel_[hotel] ho 
	INNER JOIN view_address_[address] ad ON ho.address_ID = ad.address_ID
)
ORDER BY [name] ASC;

-- @system_management_hotel_revenue_reservation_rank_sql
WITH ReservationCounts AS (
	SELECT ho.hotel_ID, COUNT(DISTINCT re.reservation_ID) AS total_reservations
	FROM view_hotel_[hotel] ho
	INNER JOIN view_room_[room] ro ON ho.hotel_ID = ro.hotel_ID
	INNER JOIN view_room_reservation_[room_reservation] rr ON ro.hotel_ID = rr.hotel_ID
		AND ro.roomNumber = rr.roomNumber
	INNER JOIN view_reservation_[reservation] re ON rr.reservation_ID = re.reservation_ID
	GROUP BY ho.hotel_ID
)
SELECT ho.hotelName,
	dbo.FN_FORMAT_PRICE(SUM(iv.totalPrice)) AS total_revenue,
	DENSE_RANK() OVER(ORDER BY SUM(iv.totalPrice) DESC) AS revenue_rank,
	rc.total_reservations,
	DENSE_RANK() OVER(ORDER BY rc.total_reservations DESC) AS reservations_rank
FROM ReservationCounts rc
LEFT OUTER JOIN view_hotel_[hotel] ho ON rc.hotel_ID = ho.hotel_ID
LEFT OUTER JOIN view_room_reservation_[room_reservation] rr ON rr.hotel_ID = ho.hotel_ID
LEFT OUTER JOIN view_reservation_[reservation] re ON re.reservation_ID = rr.reservation_ID
LEFT OUTER JOIN view_invoice_[invoice] iv ON iv.reservation_ID = re.reservation_ID
GROUP BY ho.hotelName, rc.total_reservations
ORDER BY revenue_rank;

-- @system_management_customer_spending_rank_sql
SELECT cu.customer_ID,
	dbo.FN_FULL_NAME(cu.firstName, cu.lastName) AS full_name,
	COUNT(DISTINCT re.reservation_ID) AS total_reservations,
	dbo.FN_FORMAT_PRICE(SUM(iv.totalPrice)) AS total_spent,
	DENSE_RANK() OVER (ORDER BY SUM(iv.totalPrice) DESC) AS spending_rank
FROM view_customer_[customer] cu
INNER JOIN view_reservation_[reservation] re ON re.customer_ID = cu.customer_ID
INNER JOIN view_invoice_[invoice] iv ON iv.reservation_ID = re.reservation_ID
GROUP BY cu.customer_ID, cu.firstName, cu.lastName
ORDER BY spending_rank ASC;

-- @system_management_room_category_popularity_sql
SELECT ho.hotelName, rc.categoryTitle AS category,
	COUNT(rr.reservation_ID) AS total_bookings,
	RANK() OVER (ORDER BY COUNT(rr.reservation_ID) DESC) AS popularity_rank
FROM view_roomCategory_[roomCategory] rc
INNER JOIN view_hotel_[hotel] ho ON ho.hotel_ID = rc.hotel_ID
LEFT OUTER JOIN view_room_[room] ro ON ro.roomCategory_ID = rc.roomCategory_ID
LEFT OUTER JOIN view_room_reservation_[room_reservation] rr ON rr.hotel_ID = ro.hotel_ID
	AND rr.roomNumber = ro.roomNumber
GROUP BY ho.hotelName, rc.categoryTitle
ORDER BY popularity_rank;

-- @system_management_longest_reservations_sql
SELECT DISTINCT re.reservation_ID, dbo.FN_FULL_NAME(cu.firstName, cu.lastName) AS customer, ho.hotelName,
	re.checkin, re.checkout, DATEDIFF(day, re.checkin, re.checkout) AS nights,
	DENSE_RANK() OVER (ORDER BY DATEDIFF(day, re.checkin, re.checkout) DESC) AS duration_rank
FROM view_reservation_[reservation] re
INNER JOIN view_customer_[customer] cu ON re.customer_ID = cu.customer_ID
INNER JOIN view_room_reservation_[room_reservation] rr ON rr.reservation_ID = re.reservation_ID
INNER JOIN view_hotel_[hotel] ho ON rr.hotel_ID = ho.hotel_ID
ORDER BY duration_rank;

-- @system_management_never_booked_rooms_sql
SELECT hotel_id, roomNumber
FROM view_room_[room]
EXCEPT (
	SELECT hotel_ID, roomNumber
	FROM view_room_reservation_[room_reservation]
)

-- @customer_management_get_customers_sql
SELECT cu.customer_ID, cu.firstName, cu.lastName, cu.phoneNumber, cu.email, ad.country, ad.city, ad.district, ad.streetAddress
FROM view_customer_[customer] cu
INNER JOIN view_address_[address] ad ON cu.address_ID = ad.address_ID
WHERE cu.customer_ID LIKE '%' + @customer_ID + '%'
	AND (
		cu.firstName LIKE '%' + @firstName + '%'
			AND cu.lastName LIKE '%' + @lastName + '%'
		)
	AND (
		ad.country LIKE '%' + @country + '%'
			AND ad.city LIKE '%' + @city + '%'
		)
ORDER BY cu.customer_ID ASC;

-- @customer_management_get_customers_customer_overview_kpi_0
SELECT dbo.FN_FULL_NAME(firstName, lastName) AS full_name
FROM view_customer_[customer]
WHERE customer_ID = @customer_ID;

-- @customer_management_get_customers_customer_overview_kpi_1
SELECT COALESCE(
	(
		SELECT TOP 1 ho.city
		FROM view_hotel_[hotel] ho
		INNER JOIN view_room_reservation_[room_reservation] rr ON rr.hotel_ID = ho.hotel_ID
		INNER JOIN view_reservation_[reservation] re ON re.reservation_ID = rr.reservation_ID
		WHERE re.customer_ID = @customer_ID
			AND re.checkin > GETDATE()
		ORDER BY re.checkin
	), '') AS next_destination;

-- @customer_management_get_customers_customer_overview_kpi_2
SELECT dbo.FN_FORMAT_PRICE(SUM(iv.totalPrice)) AS total_spending
FROM view_invoice_[invoice] iv
INNER JOIN view_reservation_[reservation] re ON iv.reservation_ID = re.reservation_ID
WHERE re.customer_ID = @customer_ID;

-- @customer_management_get_customers_customer_overview_insert
UPDATE view_customer_[customer]
SET firstName = @firstName,
	lastName = @lastName,
	phoneNumber = @phoneNumber,
	email = @email
WHERE customer_ID = @customer_ID;
UPDATE view_address_[address]
SET country = @country,
	city = @city,
	district = @district,
	streetAddress = @streetAddress
WHERE address_ID = (
	SELECT TOP 1 address_ID 
	FROM view_customer_[customer]
	WHERE customer_ID = @customer_ID
)

-- @customer_management_get_customers_get_customer_reservations_sql
SELECT re.reservation_ID, dbo.FN_FORMAT_PRICE(dbo.FN_GET_RESERVATION_PRICE(re.reservation_ID)) AS totalPrice, re.checkin, re.checkout, re.guests, dbo.FN_STATUS_DETAILS(re.status) AS status, COALESCE(ho.hotelName, '') AS hotelName, ho.hotel_ID, COUNT(rr.roomNumber) AS reserved_rooms
FROM view_reservation_[reservation] re
LEFT OUTER JOIN view_room_reservation_[room_reservation] rr ON re.reservation_ID = rr.reservation_ID
LEFT OUTER JOIN view_hotel_[hotel] ho ON rr.hotel_ID = ho.hotel_ID
WHERE re.customer_ID = @customer_ID
GROUP BY re.reservation_ID, re.checkin, re.checkout, re.guests, status, ho.hotelName, ho.hotel_ID
ORDER BY re.checkin ASC;

-- @customer_management_get_customers_get_customer_reservations_reservation_overview_kpi_0
SELECT ho.hotelName
FROM view_room_reservation_[room_reservation] rr
INNER JOIN view_hotel_[hotel] ho ON rr.hotel_ID = ho.hotel_ID
WHERE rr.reservation_ID = @reservation_ID;

-- @customer_management_get_customers_get_customer_reservations_reservation_overview_kpi_1
SELECT dbo.FN_STATUS_DETAILS(re.status) AS status
FROM view_reservation_[reservation] re
WHERE re.reservation_ID = @reservation_ID;

-- @customer_management_get_customers_get_customer_reservations_reservation_overview_kpi_2
SELECT dbo.FN_FORMAT_PRICE(dbo.FN_GET_RESERVATION_PRICE(@reservation_ID)) AS total_price;

-- @customer_management_get_customers_get_customer_reservations_reservation_overview_kpi_3
SELECT DATEDIFF(day, checkin, checkout) AS nights
FROM view_reservation_[reservation]
WHERE reservation_ID = @reservation_ID;

-- @customer_management_get_customers_get_customer_reservations_reservation_overview_insert
UPDATE view_reservation_[reservation]
SET status = 'C'
WHERE reservation_ID = @reservation_ID
	AND status = 'R';

-- @customer_management_get_customers_get_customer_reservations_get_reservation_additionalOptions_sql
SELECT ra.reservation_ID, ao.additionalOptionTitle AS booking_option, ra.amount, dbo.FN_FORMAT_PRICE(ra.amount * ao.price) AS total_price
FROM view_additionalOption_[additionalOption] ao
INNER JOIN view_reservation_additionalOption_[reservation_additionalOption] ra ON ao.additionalOptionTitle = ra.additionalOptionTitle
	AND ao.hotel_ID = ra.hotel_ID
WHERE ra.reservation_ID = @reservation_ID;

-- @customer_management_get_customers_get_customer_reservations_get_reservation_additionalOptions_insert
INSERT INTO view_reservation_additionalOption_system_admin (reservation_ID, additionalOptionTitle, hotel_ID, amount)
VALUES (@reservation_ID, @additionalOption_selection, @hotel_ID, @amount);

-- @customer_management_get_customers_get_customer_reservations_get_reservation_additionalOptions_opt_additionalOption_selection
SELECT additionalOptionTitle AS ID, additionalOptionTitle AS title FROM view_additionalOption_[additionalOption] WHERE hotel_ID = @hotel_ID;

-- @customer_management_get_customers_get_customer_reservations_get_reservation_additionalOptions_change_reservation_additionalOption_amount_sql
UPDATE view_reservation_additionalOption_[reservation_additionalOption]
SET amount = @amount
WHERE reservation_ID = @reservation_ID
	AND hotel_ID = @hotel_ID
	AND additionalOptionTitle = @booking_option;

-- @customer_management_get_customers_get_customer_reservations_get_reservation_additionalOptions_remove_reservation_additionalOption_sql
DELETE FROM view_reservation_additionalOption_[reservation_additionalOption]
WHERE reservation_ID = @reservation_ID
	AND hotel_ID = @hotel_ID
	AND additionalOptionTitle = @booking_option;

-- @customer_management_get_customers_search_hotel_sql
SELECT ho.hotel_ID, ho.hotelName, ho.country, ho.city, ho.district, dbo.FN_FORMAT_PRICE(MIN(rc.price)) AS min_price
FROM view_roomCategory_[roomCategory] rc
INNER JOIN view_hotel_[hotel] ho ON rc.hotel_ID = ho.hotel_ID
INNER JOIN dbo.FN_GET_AVAILABLE_ROOMS(@checkin, @checkout) ro ON ro.hotel_ID = ho.hotel_ID
WHERE ho.city LIKE '%' + @hotel_city + '%'
	AND ho.district LIKE '%' + @hotel_district + '%'
GROUP BY ho.hotel_ID, ho.hotelName, ho.country, ho.city, ho.district
HAVING SUM(rc.maxGuests) >= @guests
ORDER BY min_price ASC;

-- @customer_management_get_customers_search_hotel_get_available_roomCategories_sql
WITH RoomCategoryEquipment AS (
	SELECT rc.roomCategory_ID, STRING_AGG(eq.equipmentTitle, ', ') AS equipment
	FROM view_equipment_[equipment] eq
	INNER JOIN view_roomCategory_equipment_[roomCategory_equipment] rce ON rce.equipment_ID = eq.equipment_ID
	INNER JOIN view_roomCategory_[roomCategory] rc ON rc.roomCategory_ID = rce.roomCategory_ID
	GROUP BY rc.roomCategory_ID
)
SELECT rc.roomCategory_ID, rc.categoryTitle, rc.maxGuests, dbo.FN_FORMAT_PRICE(rc.price) AS price, CONCAT(rc.[size], 'm²') AS [size], rce.equipment, COUNT(DISTINCT ro.roomNumber) AS available_rooms
FROM view_roomCategory_[roomCategory] rc
LEFT OUTER JOIN RoomCategoryEquipment rce ON rce.roomCategory_ID = rc.roomCategory_ID
INNER JOIN dbo.FN_GET_AVAILABLE_ROOMS(@checkin, @checkout) ro ON ro.roomCategory_ID = rc.roomCategory_ID
WHERE rc.hotel_ID = @hotel_ID
GROUP BY rc.roomCategory_ID, rc.categoryTitle, rc.maxGuests, price, CONCAT(rc.[size], 'm²'), rce.equipment;

-- @customer_management_get_customers_search_hotel_get_available_roomCategories_insert
EXEC SP_CREATE_RESERVATION
	@res_customer_ID = @customer_ID,
	@res_checkin = @checkin,
	@res_checkout = @checkout,
	@res_guests = @guests,
	@res_hotel_ID = @hotel_ID,
	@res_room_count = @room_count,
	@res_roomCategory_ID = @roomCategory_selection;

-- @customer_management_get_customers_search_hotel_get_available_roomCategories_opt_roomCategory_selection
SELECT DISTINCT rc.roomCategory_ID, rc.categoryTitle FROM view_roomCategory_[roomCategory] rc INNER JOIN dbo.FN_GET_AVAILABLE_ROOMS(@checkin, @checkout) ro ON rc.hotel_ID = ro.hotel_ID AND rc.roomCategory_ID = ro.roomCategory_ID WHERE rc.hotel_ID = @hotel_ID;

-- @customer_management_get_customers_delete_customer_sql
DELETE FROM view_customer_[customer]
WHERE customer_ID = @customer_ID

-- @hotel_management_get_hotels_sql
SELECT ho.hotel_ID, ho.hotelName, ho.phoneNumber, ho.email, ad.country, ad.city, ad.district, ad.streetAddress
FROM view_hotel_[hotel] ho
INNER JOIN view_address_[address] ad ON ho.address_ID = ad.address_ID
WHERE ho.hotel_ID LIKE '%' + @hotel_ID + '%'
	AND ho.hotelName LIKE '%' + @hotelName + '%'
	AND (
		ad.country LIKE '%' + @country + '%'
			AND ad.city LIKE '%' + @city + '%'
		)
ORDER BY ho.hotel_ID ASC;

-- @hotel_management_get_hotels_insert
EXEC SP_CREATE_HOTEL
	@hotel_name = @hotelName,
	@hotel_email = @email,
	@hotel_phoneNumber = @phoneNumber,
	@hotel_country = @country,
	@hotel_city = @city,
	@hotel_district = @district,
	@hotel_streetAddress = @streetAddress;

-- @hotel_management_get_hotels_hotel_overview_kpi_0
SELECT hotelName
FROM view_hotel_[hotel]
WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_hotel_overview_kpi_1
SELECT COALESCE(SUM(re.guests), 0) AS current_guests
FROM view_reservation_[reservation] re
INNER JOIN view_room_reservation_[room_reservation] rr ON re.reservation_ID = rr.reservation_ID
WHERE GETDATE() BETWEEN re.checkin AND re.checkout
	AND re.[status] IN ('R', 'P')
	AND rr.hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_hotel_overview_kpi_2
SELECT CONCAT(CAST(CAST(COUNT(re.reservation_ID) AS FLOAT) / CAST((CASE COUNT(DISTINCT ro.roomNumber) WHEN 0 THEN 1 ELSE COUNT(DISTINCT ro.roomNumber) END) AS FLOAT) * 100 AS DECIMAL(5,2)), '%') AS occupancy
FROM view_room_[room] ro
LEFT OUTER JOIN view_room_reservation_[room_reservation] rr ON ro.hotel_ID = rr.hotel_ID
	AND ro.roomNumber = rr.roomNumber
LEFT OUTER JOIN view_reservation_[reservation] re ON rr.reservation_ID = re.reservation_ID
	AND re.[status] IN ('R', 'P')
	AND GETDATE() BETWEEN re.checkin AND re.checkout
WHERE ro.hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_hotel_overview_kpi_3
SELECT dbo.FN_FORMAT_PRICE(SUM(iv.totalPrice)) AS current_year_revenue
FROM (
	SELECT DISTINCT reservation_ID FROM view_room_reservation_[room_reservation] WHERE hotel_ID = @hotel_ID
) rr
INNER JOIN view_invoice_[invoice] iv ON iv.reservation_ID = rr.reservation_ID
WHERE YEAR(iv.invoiceDate) = YEAR(GETDATE())

-- @hotel_management_get_hotels_hotel_overview_kpi_4
SELECT COUNT(*) AS room_count
FROM view_room_[room]
WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_hotel_overview_kpi_5
SELECT COUNT(*) AS roomCategory_count
FROM view_roomCategory_[roomCategory]
WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_hotel_overview_insert
UPDATE view_hotel_[hotel]
SET hotelName = @hotelName,
	phoneNumber = @phoneNumber,
	email = @email
WHERE hotel_ID = @hotel_ID;
UPDATE view_address_[address]
SET country = @country,
	city = @city,
	district = @district,
	streetAddress = @streetAddress
WHERE address_ID = (
	SELECT TOP 1 address_ID 
	FROM view_hotel_[hotel]
	WHERE hotel_ID = @hotel_ID
);

-- @hotel_management_get_hotels_get_roomCategories_sql
SELECT rc.roomCategory_ID, rc.categoryTitle AS category, rc.maxGuests, dbo.FN_FORMAT_PRICE(rc.price) AS price, CONCAT(rc.[size], 'm²') AS [size], COUNT(DISTINCT ro.roomNumber) AS room_count
FROM view_roomCategory_[roomCategory] rc
LEFT OUTER JOIN view_room_[room] ro ON ro.roomCategory_ID = rc.roomCategory_ID
WHERE rc.hotel_ID = @hotel_ID
GROUP BY rc.roomCategory_ID, rc.categoryTitle, rc.maxGuests, price, CONCAT(rc.[size], 'm²');

-- @hotel_management_get_hotels_get_roomCategories_insert
INSERT INTO view_roomCategory_[roomCategory] (hotel_ID, categoryTitle, maxGuests, price, size)
VALUES (@hotel_ID, @category, @maxGuests, @price, @size)

-- @hotel_management_get_hotels_get_roomCategories_get_roomCategory_equipment_sql
SELECT rce.roomCategory_ID, eq.equipment_ID, eq.equipmentTitle AS equipment, rce.amount
FROM view_roomCategory_equipment_[roomCategory_equipment] rce
INNER JOIN view_equipment_[equipment] eq ON eq.equipment_ID = rce.equipment_ID
WHERE roomCategory_ID = @roomCategory_ID;

-- @hotel_management_get_hotels_get_roomCategories_get_roomCategory_equipment_insert
INSERT INTO view_roomCategory_equipment_[roomCategory_equipment] (roomCategory_ID, equipment_ID, amount)
VALUES(@roomCategory_ID, @equipment_selection, @amount);

-- @hotel_management_get_hotels_get_roomCategories_get_roomCategory_equipment_opt_equipment_selection
SELECT equipment_ID, equipmentTitle FROM view_equipment_[equipment];

-- @hotel_management_get_hotels_get_roomCategories_get_roomCategory_equipment_update_roomCategory_equipment_sql
UPDATE view_roomCategory_equipment_[roomCategory_equipment]
SET amount = @amount
WHERE roomCategory_ID = @roomCategory_ID
	AND equipment_ID = @equipment_ID;

-- @hotel_management_get_hotels_get_roomCategories_get_roomCategory_equipment_remove_roomCategory_equipment_sql
DELETE FROM view_roomCategory_equipment_[roomCategory_equipment]
WHERE roomCategory_ID = @roomCategory_ID
	AND equipment_ID = @equipment_ID;

-- @hotel_management_get_hotels_get_roomCategories_update_roomCategory_sql
UPDATE view_roomCategory_[roomCategory]
SET categoryTitle = @category,
	maxGuests = @maxGuests,
	price = @price,
	[size] = @size
WHERE roomCategory_ID = @roomCategory_ID;

-- @hotel_management_get_hotels_get_roomCategories_delete_roomCategory_sql
DELETE FROM view_roomCategory_[roomCategory]
WHERE roomCategory_ID = @roomCategory_ID;

-- @hotel_management_get_hotels_get_rooms_sql
SELECT ro.hotel_ID, ro.roomNumber, ro.floor, rc.categoryTitle AS category,
	CASE
		WHEN EXISTS (
			SELECT 1 
			FROM view_room_reservation_[room_reservation] rr
			INNER JOIN view_reservation_[reservation] re ON rr.reservation_ID = re.reservation_ID
			WHERE rr.hotel_ID = ro.hotel_ID 
				AND rr.roomNumber = ro.roomNumber
				AND re.status IN ('R', 'P')
				AND GETDATE() BETWEEN re.checkin AND re.checkout
			) THEN 'Occupied'
		WHEN EXISTS (
			SELECT 1 
			FROM view_room_reservation_[room_reservation] rr
			INNER JOIN view_reservation_[reservation] re ON rr.reservation_ID = re.reservation_ID
			WHERE rr.hotel_ID = ro.hotel_ID AND rr.roomNumber = ro.roomNumber
				AND re.status IN ('R', 'P')
				AND re.checkin > GETDATE()
			) THEN 'Reserved'
		ELSE 'Free'
	END AS room_status
FROM view_room_[room] ro
LEFT OUTER JOIN view_roomCategory_[roomCategory] rc ON ro.roomCategory_ID = rc.roomCategory_ID
WHERE ro.hotel_ID = @hotel_ID
ORDER BY ro.floor, ro.roomNumber;

-- @hotel_management_get_hotels_get_rooms_insert
INSERT INTO view_room_[room] (hotel_ID, roomNumber, roomCategory_ID, floor)
VALUES (@hotel_ID, @roomNumber, @roomCategory_selection, @floor)

-- @hotel_management_get_hotels_get_rooms_opt_roomCategory_selection
SELECT roomCategory_ID, categoryTitle FROM view_roomCategory_[roomCategory] WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_get_rooms_update_room_sql
UPDATE view_room_[room]
SET roomNumber = @newRoomNumber,
	[floor] = @floor,
	roomCategory_ID = @roomCategory_selection
WHERE hotel_ID = @hotel_ID
	AND roomNumber = @roomNumber;

-- @hotel_management_get_hotels_get_rooms_update_room_opt_roomCategory_selection
SELECT roomCategory_ID, categoryTitle FROM view_roomCategory_[roomCategory] WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_get_rooms_delete_room_sql
DELETE FROM view_room_[room]
WHERE hotel_ID = @hotel_ID
	AND roomNumber = @roomNumber;

-- @hotel_management_get_hotels_get_additionalOptions_sql
SELECT hotel_ID, additionalOptionTitle AS title, dbo.FN_FORMAT_PRICE(price) AS price
FROM view_additionalOption_[additionalOption]
WHERE hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_get_additionalOptions_insert
INSERT INTO view_additionalOption_[additionalOption] (hotel_ID, additionalOptionTitle, price) 
VALUES (@hotel_ID, @title, @price);

-- @hotel_management_get_hotels_get_additionalOptions_update_additionalOption_sql
UPDATE view_additionalOption_[additionalOption]
SET additionalOptionTitle = @newTitle,
	price = @price
WHERE hotel_ID = @hotel_ID
	AND additionalOptionTitle = @title;

-- @hotel_management_get_hotels_get_additionalOptions_delete_additionalOption_sql
DELETE FROM view_additionalOption_[additionalOption]
WHERE additionalOptionTitle = @title
	AND hotel_ID = @hotel_ID;

-- @hotel_management_get_hotels_get_reservations_sql
SELECT DISTINCT re.reservation_ID, dbo.FN_FORMAT_PRICE(dbo.FN_GET_RESERVATION_PRICE(re.reservation_ID)) AS totalPrice, re.checkin, re.checkout, re.guests, dbo.FN_STATUS_DETAILS(re.[status]) AS [status], dbo.FN_FULL_NAME(cu.firstName, cu.lastName) AS fullName, cu.phoneNumber, cu.email,
	CASE
		WHEN re.checkin > GETDATE() THEN 'Upcoming'
		WHEN re.checkout > GETDATE() THEN 'Current'
		WHEN re.checkout < GETDATE() THEN 'Prior'
		ELSE 'Invalid'
	END AS reservation_category
FROM view_reservation_[reservation] re
INNER JOIN view_room_reservation_[room_reservation] rr ON rr.reservation_ID = re.reservation_ID
INNER JOIN view_customer_[customer] cu ON cu.customer_ID = re.customer_ID
WHERE rr.hotel_ID = @hotel_ID
ORDER BY re.checkout DESC;

-- @hotel_management_get_hotels_get_reservations_create_print_invoice_sql
SELECT DISTINCT iv.reservation_ID AS invoice_ID,
	dbo.FN_FORMAT_PRICE(iv.totalPrice) AS totalPrice,
	iv.invoiceDate,
	dbo.FN_FULL_NAME(cu.firstName, cu.lastName) AS fullName,
	a1.streetAddress AS customerStreetAddress,
	a1.city AS customerCity,
	a1.country AS customerCountry,
	ho.hotelName,
	a2.streetAddress AS hotelStreetAddress,
	a2.city AS hotelCity,
	a2.country AS hotelCountry
FROM view_invoice_[invoice] iv
INNER JOIN view_reservation_[reservation] re ON iv.reservation_ID = re.reservation_ID
INNER JOIN view_customer_[customer] cu ON re.customer_ID = cu.customer_ID
INNER JOIN view_address_[address] a1 ON iv.address_ID = a1.address_ID
INNER JOIN view_room_reservation_[room_reservation] rr ON re.reservation_ID = rr.reservation_ID
INNER JOIN view_hotel_[hotel] ho ON rr.hotel_ID = ho.hotel_ID
INNER JOIN view_address_[address] a2 ON ho.address_ID = a2.address_ID
WHERE iv.reservation_ID = @reservation_ID;

-- @hotel_management_get_hotels_get_reservations_create_print_invoice_insert
INSERT INTO view_invoice_[invoice] (reservation_ID, address_ID)
VALUES (@reservation_ID,(SELECT TOP 1 address_ID FROM view_customer_[customer] WHERE customer_ID = (SELECT TOP 1 customer_ID FROM view_reservation_[reservation] WHERE reservation_ID = @reservation_ID)));

-- @hotel_management_get_hotels_get_reservations_delete_invoice_sql
DELETE FROM view_invoice_[invoice] WHERE reservation_ID = @reservation_ID

-- @hotel_management_get_hotels_get_reservations_cancel_reservation_hotel_staff_sql
UPDATE view_reservation_[reservation]
SET status = 'C'
WHERE reservation_ID = @reservation_ID
	AND status = 'R'

-- @hotel_management_get_hotels_room_booking_rank_sql
SELECT rc.roomCategory_ID, rc.categoryTitle AS category, dbo.FN_FORMAT_PRICE(rc.price) AS price,
	COUNT(rr.reservation_ID) AS total_bookings,
	RANK() OVER (ORDER BY COUNT(rr.reservation_ID) DESC) AS booking_rank
FROM view_roomCategory_[roomCategory] rc
LEFT OUTER JOIN view_room_[room] ro ON ro.roomCategory_ID = rc.roomCategory_ID
LEFT OUTER JOIN view_room_reservation_[room_reservation] rr ON rr.hotel_ID = ro.hotel_ID
	AND rr.roomNumber = ro.roomNumber
WHERE rc.hotel_ID = @hotel_ID
GROUP BY rc.roomCategory_ID, rc.categoryTitle, rc.price
ORDER BY booking_rank ASC;

-- @hotel_management_get_hotels_peak_checkin_days_sql
WITH AllWeekdays AS (
	SELECT 1 AS day_number, 'Monday' AS weekday
	UNION ALL SELECT 2, 'Tuesday'
	UNION ALL SELECT 3, 'Wednesday'
	UNION ALL SELECT 4, 'Thursday'
	UNION ALL SELECT 5, 'Friday'
	UNION ALL SELECT 6, 'Saturday'
	UNION ALL SELECT 7, 'Sunday'
), HotelReservations AS (
	SELECT re.reservation_ID, DATENAME(weekday, re.checkin) AS weekday
	FROM view_reservation_[reservation] re
	INNER JOIN view_room_reservation_[room_reservation] rr ON rr.reservation_ID = re.reservation_ID
	WHERE rr.hotel_ID = @hotel_ID
)
SELECT aw.weekday, COUNT(DISTINCT hr.reservation_ID) AS total_reservations,
	RANK() OVER (ORDER BY COUNT(DISTINCT hr.reservation_ID) DESC) AS checkin_popularity_rank
FROM AllWeekdays aw
LEFT OUTER JOIN HotelReservations hr ON aw.weekday = hr.weekday
GROUP BY aw.weekday;

-- @hotel_management_get_hotels_delete_hotel_sql
DELETE FROM view_hotel_[hotel]
WHERE hotel_ID = @hotel_ID;
