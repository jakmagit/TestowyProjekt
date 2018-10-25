
----------ROZLICZENIE WPŁAT BANKOWYCH NA KONTA KSIĘGOWE (analityka)---------------------
----------ZESTAWIENIE WPŁAT BANKOWYCH TRANS COLLECT (analityka)---------------------


-- 2018.10.15

/*to jest wersja, która:
- liczy anulowane rozliczenia na minus (bo te rozliczone pojawiają się też na plus a potem na plus jest także kolejne ich wydanie) ALE
- nie liczy przeksięgowanych środków, tzn. - była wpłata i tyle, a to czy została ona przeksięgowana czy nie, to już nas nie interesuje
Nie jest to do końca poprawne (z tymi przeksięgowaniami), ale okazuje się, że to zgadza się z raportami generowanymi w usos
(tzn. kiedy uwzględnimy raporty 'wpłaty bankowe' ("Płatności -> Słowniki") i "nierozliczone wpłaty" ("Płatności -> nierozliczone wpłaty"))
*/


select t.DATA_PLATN, o.NAZWISKO || ' ' || o.IMIE || ' (' || s.INDEKS || ')' "OSOBA", 
    (CASE
        WHEN d.tresc like 'Odsetki od należności%'
        THEN
            substr(d.tresc, 0, 21)
        ELSE
            d.tresc
        END) "TYTUŁ",
     
     dd.MA AS "KWOTA",
  
    -- tutaj są dwie kolumny z numerami kont bankowych (jak coś jest w jednej, to w drugiej jest null i odwrotnie), dlatego trzeba to włożyć do jednej kolumny
    (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL 
         ELSE
            ddd.UF_KNT_SYMBOL
         END) "KONTO"
   
-- wychodzimy od TRANSAKCJI, które są (WHERE) z danego okresu (DATA_PLATN) i są przelewami na konto bankowe (KOD = UEK-WPL-WB)
-- z tego otrzymujemy jego konto księgowe (UF_KNT_SYMBOL) oraz ID TRANSAKCJI (ID)
from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL

inner join DZ_OSOBY o
on k.OS_ID = o.ID

left join DZ_STUDENCI s
on o.ID = s.OS_ID and s.TYP_IND_KOD = 'C'

-- w DEKRETACH znajdujemy wszystkie zapisy, które mają ten sam numer transakcji (UF_TRA_ID) i te, które mają ujemną wartość (MA) - to jest wydatkowanie tej kwoty
-- odstępstwem jest 'Anulowanie transakcji' bo tutaj kwota jest na plus
join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')


/* Mamy wydatki (może być ich wiele), przy każdym jest (UF_DOKKS_ID), bierzemy każdy i:
- znajduję w DEKRETY rekordy = UF_DOKKS_ID  i będą dwa zapisy: kwota z dodatnim (MA) to kwota za co było zapłacone, ale wyjątkiem jest 'Anulowanie rozliczenia' (bo to jest na minus)
i 'Przeksięgowanie wpłaty' (tego nie bierzemy pod uwagę).
*/
join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia' and dd.Tresc != 'Przeksięgowanie wpłaty') -- tutaj też znajdziemy odsetki
         or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  

/* Bierzemy z tego ww. UF_TRA_ID i idziemy z tym do tabeli TRANSAKCJE (znajdujemy rekord o takim ID) przy tym rekordzie jest id z tabeli PROPOZYCJE OPLAT (UP_PROPOPL_ID).
Znajdujemy rekord o takim ID i tam jest UF_KNT_SYMBOL (konto księgowe związane z produktem, na który poszły pieniądze) - i mamy to co trzeba, ale wyjątkiem są ODSETKI
*/

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

/*Dlatego jeszcze raz idziemy do tabeli DEKRETY i znajdujemy tam wszystkie wpisy o takim samym ID TRANSAKCJI ale treści 'Odsetki'
dopiero stąd weźmiemy prawidłowy numer konta księgowego. W efekcie dostajemy jeszcze jedną kolumnę (z nullami i wartościami), ale powyżej (SELECT) je łączymy w jedno.
*/
left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'

where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/10/01' and t.DATA_PLATN <= '18/10/15'
order by t.DATA_PLATN
;


--------------PODSUMOWANIE WPŁAT BANKOWYCH STUDENTÓW NA KONTA KSIĘGOWE (syntetyka) -------------------
--- opis jest w analityce
--- 2018.10.15

SELECT DISTINCT SUM(dd.MA) over (PARTITION by p.UF_KNT_SYMBOL, ddd.UF_KNT_SYMBOL) as SUMA,
     (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL 
         ELSE
            ddd.UF_KNT_SYMBOL
         END) AS KONTO
  
from USP_F_TRANSAKCJE t

join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')

join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia' and dd.Tresc != 'Przeksięgowanie wpłaty') -- tutaj też łapią się odsetki
        --or (dd.ma > 0 and dd.Tresc = 'Odsetki')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'

where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/10/01' and t.DATA_PLATN <= '18/10/15' 
order by "KONTO"
;



























ALGORYTM SZUKANIA SPOSOBU ROZLICZENIA WPŁAT BANKOWYCH (na jakie konto księgowe trafiła wpłata bankowa)

1. zaczynamy od TRANSAKCJE, gdzie jesteśmy w stanie znaleźć wszystkie przelewy (KOD = UEK-WPL-WB) gościa z danego okresu (DATA_PLATN) i jego konto (UF_KNT_SYMBOL)
i mamy numer id transakcji (ID)

// TODO coś z tym trzeba zrobić kk

2. w DEKRETACH znajduję wszystkie zapisy, które mają ten sam numer transakcji (UF_TRA_ID) i te, które mają ujemną wartość (MA) to jest wydatkowanie tej kwoty
(za sierpień jest 1396 rekordów)
UWAGA: jest problem z anulowaniem rozliczenia, bo jak się anuluje to idzie 'na plus' a potem po przypisaniu dalej też ma wartość ujemną. Co znaczy, że jedna wpłata będzie liczona kilka razy (zostało to oprogramowane)

- mam wydatki (może być ich wiele), przy każdym jest (UF_DOKKS_ID), biorę każdego i:
* znajduję w DEKRETY rekordy = UF_DOKKS_ID  i będą dwa zapisy: kwota z dodatnim (MA) to kwota za co zapłaciliśmy
* bierzemy z tego UF_TRA_ID i idziemy z tym do tabeli TRANSAKCJE (znajdujemy rekord o takim ID)
* przy tym rekordzie jest id z tabeli PROPOZYCJE OPLAT (UP_PROPOPL_ID)
* znajdujemy rekord o takim ID i tam jest UF_KNT_SYMBOL (konto księgowe związane z produktem, na który poszły pieniądze) - i mamy to co trzeba


Ciekawa sytuacja z anulowaniem wpłat: 
Patryk Grądziel: 200-0000020622
id transakcji = 3344





TO JEST TA PROCEDURA:


--------------------ROZLICZENIE WPŁAT BANKOWYCH STUDENTA - na jakie konto księgowe trafiła wpłata studenta (wersja 2)----------------------------
pią, 12 paź 2018, 20:43:00 CEST

/*to jest wersja, która liczy:
- anulowane rozliczenia na minus (bo te rozliczone pojawiają się też na plus a potem na plus jest także kolejne ich wydanie)
- przeksięgowane środki na plus (bo w końcu były przelane na konto bankowe), ale nie podąża za nimi i wyświetlany jest tylko komunikat o tym, że są przeksięgowane

Problem: te wyliczenia nie zgadzają się z raportami, które generowane są w usos, tzn. kiedy uwzględnimy raporty 'wpłaty bankowe' i nierozliczone wpłaty'

*/


select t.DATA_PLATN, k.symbol, k.nazwa, t.opis, d.tresc, d.UF_DOKKS_ID, d.MA, dd.UF_DOKKS_ID "DOKKS_ID", dd.ma "DD.MA" , dd.uf_tra_id "DD.UF_TRA_ID", tt.UP_PROPOPL_ID,

(CASE
         WHEN d.TRESC = 'Przeksięgowanie wpłaty'
         THEN
                'PRZEKSIĘGOWANIE!'
         ELSE
            p.UF_KNT_SYMBOL
         END) "KONTO"

from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL

inner join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID and (d.MA < 0 or d.tresc like 'Anulowanie%')
/*przeksięgowanie wplaty nie jest widoczne jako wplata (pomimo, ze w bazie tak jest zapisane) */


inner join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID 
  
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia')
        or (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia' and dd.tresc = 'Przeksięgowanie wpłaty')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID
    
left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

  where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/08/01' and t.DATA_PLATN <= '18/08/31' and t.uf_knt_symbol = '200-0000019314' --'200-0000019862'
  
--group by  t.DATA_PLATN,  k.nazwa,  d.tresc, dd.MA , p.UF_KNT_SYMBOL
  
   order by t.UF_KNT_SYMBOL
   --order by p.UF_KNT_SYMBOL
  --  order by t.DATA_PLATN
;


--------------------ROZLICZENIE WPŁAT BANKOWYCH STUDENTA - na jakie konto księgowe trafiła wpłata studenta (wersja 1)----------------------------


/*to jest wersja, która liczy:
anulowane rozliczenia na minus (bo te rozliczone pojawiają się też na plus a potem na plus jest także kolejne ich wydanie)
ale
nie liczy przeksięgowanych środków, tzn. - była jedna wpłata a to czy została ona przeksięgowana czy nie, to już nas nie interesuje

Nie jest to do końca poprawne (z tymi przeksięgowaniami), ale okazuje się, że to zgadza się z raportami generowanymi wusos, tzn. kiedy uwzględnimy raporty 'wpłaty bankowe' (z "Płatności -> Słowniki") i "nierozliczone wpłaty" (ale z "Płatności -> nierozliczone wpłaty")

*/

select t.DATA_PLATN, k.nazwa, d.tresc, dd.MA AS "KWOTA", p.UF_KNT_SYMBOL as "KONTO"

from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL

inner join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID and (d.MA < 0 or d.tresc like 'Anulowanie%')

inner join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

inner join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/09/01' and t.DATA_PLATN <= '18/09/30'

group by t.DATA_PLATN, k.nazwa, d.tresc, dd.MA , p.UF_KNT_SYMBOL

-- order by t.UF_KNT_SYMBOL
-- order by p.UF_KNT_SYMBOL
order by t.DATA_PLATN
;

-------------------------poprawka wersji 1 (z uwzględnieniem odsetek!) 
-- pon, 15 paź 2018, 16:23:07 CEST

select t.DATA_PLATN, k.nazwa, o.NAZWISKO || ' ' || o.IMIE || ' (' || s.INDEKS || ')' "OSOBA", t.id "ID TRANS",

    (CASE
        WHEN d.tresc like 'Odsetki od należności%'
        THEN
            substr(d.tresc, 0, 21)
        ELSE
            d.tresc
        END) "TYTUŁ",

    dd.MA AS "KWOTA", d.UF_KNT_SYMBOL, dd.UF_TRA_ID,

    (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL
         ELSE
            ddd.UF_KNT_SYMBOL
         END) "KONTO"


from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL

inner join DZ_OSOBY o
on k.OS_ID = o.ID

left join DZ_STUDENCI s
on o.ID = s.OS_ID and s.TYP_IND_KOD = 'C'

 join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')


join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia') -- tutaj też łapią się odsetki
        --or (dd.ma > 0 and dd.Tresc = 'Odsetki')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'


where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/08/01' and t.DATA_PLATN <= '18/08/31'


order by t.DATA_PLATN
;



----------ROZLICZENIE WPŁAT BANKOWYCH NA KONTA KSIĘGOWE---------------------
-- pon, 15 paź 2018, 17:17:36 CEST
select t.DATA_PLATN, k.nazwa, o.NAZWISKO || ' ' || o.IMIE || ' (' || s.INDEKS || ')' "OSOBA", t.id "ID TRANS", 
    (CASE
        WHEN d.tresc like 'Odsetki od należności%'
        THEN
            substr(d.tresc, 0, 21)
        ELSE
            d.tresc
        END) "TYTUŁ",
        
    dd.MA AS "KWOTA", d.UF_KNT_SYMBOL, dd.UF_TRA_ID,
  
    (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL 
         ELSE
            ddd.UF_KNT_SYMBOL
         END) "KONTO"
   
from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL

inner join DZ_OSOBY o
on k.OS_ID = o.ID

left join DZ_STUDENCI s
on o.ID = s.OS_ID and s.TYP_IND_KOD = 'C'

 join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')


join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia' and dd.Tresc != 'Przeksięgowanie wpłaty') -- tutaj też łapią się odsetki
        --or (dd.ma > 0 and dd.Tresc = 'Odsetki')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'

where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/10/01' and t.DATA_PLATN <= '18/10/15'
order by t.DATA_PLATN
;









---------------PODSUMOWANIE WPŁAT NA KONCIE ---------------------------


pią, 12 paź 2018, 18:57:23 CEST
---PODSUMOWANIE WPŁAT NA KONTA


SELECT DISTINCT SUM(dd.MA) over (PARTITION by p.UF_KNT_SYMBOL) as SUMA, p.UF_KNT_SYMBOL


from USP_F_TRANSAKCJE t

inner join USP_F_KONTA k
on t.UF_KNT_SYMBOL = k.SYMBOL


inner join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID and (d.MA < 0 or d.tresc like 'Anulowanie%')

inner join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID
    
inner join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

  
  where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/08/01' and t.DATA_PLATN <= '18/09/30'
  
  
  order by p.UF_KNT_SYMBOL
    -- order by t.DATA_PLATN

;


pon, 15 paź 2018, 16:49:42 CEST
---PODSUMOWANIE WPŁAT NA KONTA
SELECT DISTINCT SUM(dd.MA) over (PARTITION by p.UF_KNT_SYMBOL, ddd.UF_KNT_SYMBOL) as SUMA,
     (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL 
         ELSE
            ddd.UF_KNT_SYMBOL
         END) AS KONTO

  
from USP_F_TRANSAKCJE t

join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')

join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia') -- tutaj też łapią się odsetki
        --or (dd.ma > 0 and dd.Tresc = 'Odsetki')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  

inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'

  
  where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/10/03' and t.DATA_PLATN <= '18/10/03'
   
  order by "KONTO"

;



---PODSUMOWANIE WPŁAT NA KONTA
---pon, 15 paź 2018, 17:16:09 CEST
SELECT DISTINCT SUM(dd.MA) over (PARTITION by p.UF_KNT_SYMBOL, ddd.UF_KNT_SYMBOL) as SUMA,
     (CASE
         WHEN p.UF_KNT_SYMBOL is not null
         THEN
             p.UF_KNT_SYMBOL 
         ELSE
            ddd.UF_KNT_SYMBOL
         END) AS KONTO
  
from USP_F_TRANSAKCJE t

join USP_F_DEKRETY d
on t.id = d.UF_TRA_ID  and (d.MA < 0 or d.tresc like 'Anulowanie%')

join USP_F_DEKRETY dd
on d.UF_DOKKS_ID = dd.UF_DOKKS_ID
    and (
        (dd.ma > 0 and dd.Tresc != 'Anulowanie rozliczenia' and dd.Tresc != 'Przeksięgowanie wpłaty') -- tutaj też łapią się odsetki
        --or (dd.ma > 0 and dd.Tresc = 'Odsetki')
        or (dd.ma < 0 and dd.Tresc = 'Anulowanie rozliczenia')
         )  


inner join USP_F_TRANSAKCJE tt
on tt.ID = dd.UF_TRA_ID

left join USP_P_PROPOZYCJE_OPLAT p
on tt.UP_PROPOPL_ID = p.ID

left join USP_F_DEKRETY ddd
on ddd.UF_TRA_ID = dd.UF_TRA_ID and ddd.tresc = 'Odsetki'

  
  where t.KOD = 'UEK-WPL-WB' and t.DATA_PLATN >= '18/10/01' and t.DATA_PLATN <= '18/10/15' 
  order by "KONTO"
;


-- oto jest odgałęzienie mojego projektu
-- w tym rozgałęzieniu coś sobie dopisałem


