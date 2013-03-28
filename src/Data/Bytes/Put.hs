{-# LANGUAGE CPP #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
--------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2013
-- License   :  BSD3
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- This module generalizes the @binary@ 'B.PutM' and @cereal@ 'S.PutM'
-- monads in an ad hoc fashion to permit code to be written that is
-- compatible across them.
--
-- Moreover, this class permits code to be written to be portable over
-- various monad transformers applied to these as base monads.
--------------------------------------------------------------------
module Data.Bytes.Put
  ( MonadPut(..)
  , puts
  , Serializable(..)
  , GSerializable(..)
  ) where

import Control.Monad.Reader
import Control.Monad.RWS.Lazy as Lazy
import Control.Monad.RWS.Strict as Strict
import Control.Monad.State.Lazy as Lazy
import Control.Monad.State.Strict as Strict
import Control.Monad.Writer.Lazy as Lazy
import Control.Monad.Writer.Strict as Strict
import qualified Data.Binary.Put as B
import Data.ByteString as Strict
import Data.ByteString.Lazy as Lazy
import Data.Foldable as Foldable
import Data.Int
import qualified Data.Serialize.Put as S
import Data.Word
import GHC.Generics

------------------------------------------------------------------------------
-- MonadPut
------------------------------------------------------------------------------

class Monad m => MonadPut m where
  -- | Efficiently write a byte into the output buffer
  putWord8 :: Word8 -> m ()
#ifndef HLINT
  default putWord8 :: (m ~ t n, MonadTrans t, MonadPut n) => Word8 -> m ()
  putWord8 = lift . putWord8
  {-# INLINE putWord8 #-}
#endif

  -- | An efficient primitive to write a strict 'Strict.ByteString' into the output buffer.
  --
  -- In @binary@ this flushes the current buffer, and writes the argument into a new chunk.
  putByteString     :: Strict.ByteString -> m ()
#ifndef HLINT
  default putByteString :: (m ~ t n, MonadTrans t, MonadPut n) => Strict.ByteString -> m ()
  putByteString = lift . putByteString
  {-# INLINE putByteString #-}
#endif

  -- | Write a lazy 'Lazy.ByteString' efficiently.
  --
  -- With @binary@, this simply appends the chunks to the output buffer
  putLazyByteString :: Lazy.ByteString -> m ()
#ifndef HLINT
  default putLazyByteString :: (m ~ t n, MonadTrans t, MonadPut n) => Lazy.ByteString -> m ()
  putLazyByteString = lift . putLazyByteString
  {-# INLINE putLazyByteString #-}
#endif

  -- | Pop the 'ByteString' we have constructed so far, if any, yielding a
  -- new chunk in the result 'ByteString'.
  --
  -- If we're building a strict 'Strict.ByteString' with @cereal@ then this does nothing.
  flush :: m ()
#ifndef HLINT
  default flush :: (m ~ t n, MonadTrans t, MonadPut n) => m ()
  flush = lift flush
  {-# INLINE flush #-}
#endif

  -- | Write a 'Word16' in little endian format
  putWord16le   :: Word16 -> m ()
#ifndef HLINT
  default putWord16le :: (m ~ t n, MonadTrans t, MonadPut n) => Word16 -> m ()
  putWord16le = lift . putWord16le
  {-# INLINE putWord16le #-}
#endif

  -- | Write a 'Word16' in big endian format
  putWord16be   :: Word16 -> m ()
#ifndef HLINT
  default putWord16be :: (m ~ t n, MonadTrans t, MonadPut n) => Word16 -> m ()
  putWord16be = lift . putWord16be
  {-# INLINE putWord16be #-}
#endif

  -- | /O(1)./ Write a 'Word16' in native host order and host endianness.
  -- For portability issues see 'putWordhost'.
  putWord16host :: Word16 -> m ()
#ifndef HLINT
  default putWord16host :: (m ~ t n, MonadTrans t, MonadPut n) => Word16 -> m ()
  putWord16host = lift . putWord16host
  {-# INLINE putWord16host #-}
#endif

  -- | Write a 'Word32' in little endian format
  putWord32le   :: Word32 -> m ()
#ifndef HLINT
  default putWord32le :: (m ~ t n, MonadTrans t, MonadPut n) => Word32 -> m ()
  putWord32le = lift . putWord32le
  {-# INLINE putWord32le #-}
#endif

  -- | Write a 'Word32' in big endian format
  putWord32be   :: Word32 -> m ()
#ifndef HLINT
  default putWord32be :: (m ~ t n, MonadTrans t, MonadPut n) => Word32 -> m ()
  putWord32be = lift . putWord32be
  {-# INLINE putWord32be #-}
#endif

  -- | /O(1)./ Write a 'Word32' in native host order and host endianness.
  -- For portability issues see @putWordhost@.
  putWord32host :: Word32 -> m ()
#ifndef HLINT
  default putWord32host :: (m ~ t n, MonadTrans t, MonadPut n) => Word32 -> m ()
  putWord32host = lift . putWord32host
  {-# INLINE putWord32host #-}
#endif

  -- | Write a 'Word64' in little endian format
  putWord64le   :: Word64 -> m ()
#ifndef HLINT
  default putWord64le :: (m ~ t n, MonadTrans t, MonadPut n) => Word64 -> m ()
  putWord64le = lift . putWord64le
  {-# INLINE putWord64le #-}
#endif

  -- | Write a 'Word64' in big endian format
  putWord64be   :: Word64 -> m ()
#ifndef HLINT
  default putWord64be :: (m ~ t n, MonadTrans t, MonadPut n) => Word64 -> m ()
  putWord64be = lift . putWord64be
  {-# INLINE putWord64be #-}
#endif

  -- | /O(1)./ Write a 'Word64' in native host order and host endianness.
  -- For portability issues see @putWordhost@.
  putWord64host :: Word64 -> m ()
#ifndef HLINT
  default putWord64host :: (m ~ t n, MonadTrans t, MonadPut n) => Word64 -> m ()
  putWord64host = lift . putWord64host
  {-# INLINE putWord64host #-}
#endif


  -- | /O(1)./ Write a single native machine word. The word is
  -- written in host order, host endian form, for the machine you're on.
  -- On a 64 bit machine the Word is an 8 byte value, on a 32 bit machine,
  -- 4 bytes. Values written this way are not portable to
  -- different endian or word sized machines, without conversion.
  putWordhost :: Word -> m ()
#ifndef HLINT
  default putWordhost :: (m ~ t n, MonadTrans t, MonadPut n) => Word -> m ()
  putWordhost = lift . putWordhost
  {-# INLINE putWordhost #-}
#endif

instance MonadPut B.PutM where
  putWord8 = B.putWord8
  {-# INLINE putWord8 #-}
  putByteString = B.putByteString
  {-# INLINE putByteString #-}
  putLazyByteString = B.putLazyByteString
  {-# INLINE putLazyByteString #-}
  flush = B.flush
  {-# INLINE flush #-}
  putWord16le   = B.putWord16le
  {-# INLINE putWord16le #-}
  putWord16be   = B.putWord16be
  {-# INLINE putWord16be #-}
  putWord16host = B.putWord16host
  {-# INLINE putWord16host #-}
  putWord32le   = B.putWord32le
  {-# INLINE putWord32le #-}
  putWord32be   = B.putWord32be
  {-# INLINE putWord32be #-}
  putWord32host = B.putWord32host
  {-# INLINE putWord32host #-}
  putWord64le   = B.putWord64le
  {-# INLINE putWord64le #-}
  putWord64be   = B.putWord64be
  {-# INLINE putWord64be #-}
  putWord64host = B.putWord64host
  {-# INLINE putWord64host #-}
  putWordhost   = B.putWordhost
  {-# INLINE putWordhost #-}

instance MonadPut S.PutM where
  putWord8 = S.putWord8
  {-# INLINE putWord8 #-}
  putByteString = S.putByteString
  {-# INLINE putByteString #-}
  putLazyByteString = S.putLazyByteString
  {-# INLINE putLazyByteString #-}
  flush = S.flush
  {-# INLINE flush #-}
  putWord16le   = S.putWord16le
  {-# INLINE putWord16le #-}
  putWord16be   = S.putWord16be
  {-# INLINE putWord16be #-}
  putWord16host = S.putWord16host
  {-# INLINE putWord16host #-}
  putWord32le   = S.putWord32le
  {-# INLINE putWord32le #-}
  putWord32be   = S.putWord32be
  {-# INLINE putWord32be #-}
  putWord32host = S.putWord32host
  {-# INLINE putWord32host #-}
  putWord64le   = S.putWord64le
  {-# INLINE putWord64le #-}
  putWord64be   = S.putWord64be
  {-# INLINE putWord64be #-}
  putWord64host = S.putWord64host
  {-# INLINE putWord64host #-}
  putWordhost   = S.putWordhost
  {-# INLINE putWordhost #-}

instance MonadPut m => MonadPut (Lazy.StateT s m)
instance MonadPut m => MonadPut (Strict.StateT s m)
instance MonadPut m => MonadPut (ReaderT e m)
instance (MonadPut m, Monoid w) => MonadPut (Lazy.WriterT w m)
instance (MonadPut m, Monoid w) => MonadPut (Strict.WriterT w m)
instance (MonadPut m, Monoid w) => MonadPut (Lazy.RWST r w s m)
instance (MonadPut m, Monoid w) => MonadPut (Strict.RWST r w s m)

puts :: MonadPut m => (a -> m ()) -> [a] -> m ()
puts f xs = serialize (Prelude.length xs) >> Foldable.mapM_ f xs
{-# INLINE puts #-}

------------------------------------------------------------------------------
-- Serializable
------------------------------------------------------------------------------


class Serializable a where
  serialize :: MonadPut m => a -> m ()
#ifndef HLINT
  default serialize :: (MonadPut m, GSerializable (Rep a), Generic a) => a -> m ()
  serialize = gserialize . from
#endif

instance Serializable a => Serializable [a]
instance Serializable a => Serializable (Maybe a)
instance (Serializable a, Serializable b) => Serializable (Either a b)

instance Serializable Bool where

instance Serializable Char where
  serialize = putWord32host . fromIntegral . fromEnum

instance Serializable Word where
  serialize = putWordhost

instance Serializable Word64 where
  serialize = putWord64host

instance Serializable Word32 where
  serialize = putWord32host

instance Serializable Word16 where
  serialize = putWord16host

instance Serializable Word8 where
  serialize = putWord8

instance Serializable Int where
  serialize = putWordhost . fromIntegral

instance Serializable Int64 where
  serialize = putWord64host . fromIntegral

instance Serializable Int32 where
  serialize = putWord32host . fromIntegral

instance Serializable Int16 where
  serialize = putWord16host . fromIntegral

instance Serializable Int8 where
  serialize = putWord8 . fromIntegral

------------------------------------------------------------------------------
-- GSerializable
------------------------------------------------------------------------------

-- | Used internally to provide generic serialization
class GSerializable f where
  gserialize :: MonadPut m => f a -> m ()

instance GSerializable U1 where
  gserialize U1 = return ()

instance GSerializable V1 where
  gserialize _ = fail "I looked into the void. It looked back"

instance (GSerializable f, GSerializable g) => GSerializable (f :*: g) where
  gserialize (f :*: g) = do
    gserialize f
    gserialize g

instance (GSerializable f, GSerializable g) => GSerializable (f :+: g) where
  gserialize (L1 x) = putWord8 0 >> gserialize x
  gserialize (R1 y) = putWord8 0 >> gserialize y

instance GSerializable f => GSerializable (M1 i c f) where
  gserialize (M1 x) = gserialize x

instance Serializable a => GSerializable (K1 i a) where
  gserialize (K1 x) = serialize x

------------------------------------------------------------------------------
-- Serializable1
------------------------------------------------------------------------------

class Serializable1 f where
  serialize1 :: (MonadPut m, Serializable a) => f a -> m ()
#ifndef HLINT
  default serialize1 :: (MonadPut m, GSerializable1 (Rep1 f), Serializable a, Generic1 f) => f a -> m ()
  serialize1 = gserialize1 . from1
#endif

------------------------------------------------------------------------------
-- GSerializable1
------------------------------------------------------------------------------

-- | Used internally to provide generic serialization
class GSerializable1 f where
  gserialize1 :: (MonadPut m, Serializable a) => f a -> m ()

instance GSerializable1 Par1 where
  gserialize1 (Par1 a) = serialize a

instance GSerializable1 f => GSerializable1 (Rec1 f) where
  gserialize1 (Rec1 fa) = gserialize1 fa

-- instance (Serializable1 f, GSerializable1 g) => GSerializable1 (f :.: g) where

instance GSerializable1 U1 where
  gserialize1 U1 = return ()

instance GSerializable1 V1 where
  gserialize1 _ = fail "I looked into the void. It looked back"

instance (GSerializable1 f, GSerializable1 g) => GSerializable1 (f :*: g) where
  gserialize1 (f :*: g) = do
    gserialize1 f
    gserialize1 g

instance (GSerializable1 f, GSerializable1 g) => GSerializable1 (f :+: g) where
  gserialize1 (L1 x) = putWord8 0 >> gserialize1 x
  gserialize1 (R1 y) = putWord8 0 >> gserialize1 y

instance GSerializable f => GSerializable1 (M1 i c f) where
  gserialize1 (M1 x) = gserialize x

instance Serializable a => GSerializable1 (K1 i a) where
  gserialize1 (K1 x) = serialize x
