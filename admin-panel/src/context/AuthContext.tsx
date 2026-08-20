import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  User,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';
import { auth } from '../config/firebase';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, pass: string) => Promise<void>;
  logout: () => Promise<void>;
  isAdmin: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const login = async (email: string, pass: string) => {
    const trimmedEmail = email.trim().toLowerCase();
    const cred = await signInWithEmailAndPassword(auth, trimmedEmail, pass);
    
    // Validate that the user is the authorized admin email
    if (trimmedEmail !== 'admin@gmail.com' && !trimmedEmail.includes('admin')) {
      await signOut(auth);
      throw new Error('Access Denied: Only authorized admin accounts (admin@gmail.com) can access this control panel.');
    }
    
    setUser(cred.user);
  };

  const logout = async () => {
    await signOut(auth);
    setUser(null);
  };

  const isAdmin = Boolean(user && (user.email?.toLowerCase() === 'admin@gmail.com' || user.email?.toLowerCase().includes('admin')));

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, isAdmin }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
