
-- Funciones de fmt

(+|) :: Show a => String -> a -> String
(+|) xs a = xs ++ show a

(|+) :: String -> String -> String
(|+) = (++)



--  (Cantidad de cpu, Cantidad de io)
tests :: [(Word, Word)]
tests = [(cpu, io) | cpu <- [0..2], io <- [0..2]]


-- Comando para pasarle a xv6 para ese caso de test
comandos :: (Word, Word) -> String
comandos (cpu, io) = unlines $
  ["cpubench > "+| cpu |+"cpu"+| io |+"io_cpu"+| ncpu |+" &"
    | ncpu <- [1..cpu]
  ]
  ++ ["iobench > "+| cpu |+"cpu"+| io |+"io_io"+| nio |+" &"
    | nio <- [1..io]
  ]

-- Archivos generados dentro de xv6 en este caso del test
archivos :: (Word, Word) -> [String]
archivos (cpu, io) =
  [""+| cpu |+"cpu"+| io |+"io_cpu"+| ncpu
    | ncpu <- [1..cpu]
  ]
  ++ [""+| cpu |+"cpu"+| io |+"io_io"+| nio
    | nio <- [1..io]
  ]


-- Comandos de todos los test
comandos_test :: [String]
comandos_test = comandos <$> tests

-- Todos los archivos generados por los test
archivos_test :: [String]
archivos_test = tests >>= archivos

