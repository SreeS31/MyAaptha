import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface AuthState {
  token: string | null;
  userId: string | null;
  fullName: string | null;
}

const initialState: AuthState = {
  token: typeof window !== 'undefined' ? localStorage.getItem('cn_token') : null,
  userId: null,
  fullName: null,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setCredentials(state, action: PayloadAction<{ token: string; userId: string; fullName: string }>) {
      state.token = action.payload.token;
      state.userId = action.payload.userId;
      state.fullName = action.payload.fullName;
      if (typeof window !== 'undefined') {
        localStorage.setItem('cn_token', action.payload.token);
      }
    },
    logout(state) {
      state.token = null;
      state.userId = null;
      state.fullName = null;
      if (typeof window !== 'undefined') localStorage.removeItem('cn_token');
    },
  },
});

export const { setCredentials, logout } = authSlice.actions;
export default authSlice.reducer;
